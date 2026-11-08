import 'package:flutter_test/flutter_test.dart';
import 'package:serenity_reflection/data/app_database.dart';
import 'package:serenity_reflection/data/local_repository.dart';
import 'package:serenity_reflection/security/sensitive_field_codec.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late LocalRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    database = await AppDatabase.forTesting(raw);
    repository = LocalRepository(database);
  });

  tearDown(() => database.close());

  Future<String> createLegacyDatabase() async {
    final path = '/tmp/sukoon-v1-${DateTime.now().microsecondsSinceEpoch}.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
          CREATE TABLE reflection_entries (
            id TEXT PRIMARY KEY, body TEXT NOT NULL,
            mood TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL, deleted_at INTEGER
          )
        ''');
          await db.execute('''
          CREATE TABLE session_records (
            id TEXT PRIMARY KEY, kind TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL, completed_at INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE mood_checkins (
            id TEXT PRIMARY KEY, mood TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL
          )
        ''');
          await db.insert('reflection_entries', {
            'id': 'legacy-r',
            'body': 'بيانات قديمة',
            'mood': 'هادئ',
            'created_at': 1,
            'updated_at': 1,
          });
          await db.insert('mood_checkins', {
            'id': 'legacy-m',
            'mood': 'متوازن',
            'note': 'ملاحظة قديمة',
            'created_at': 1,
          });
        },
      ),
    );
    await legacy.close();
    return path;
  }

  test(
    'persists and reads the latest journal, mood, and session count',
    () async {
      await database.saveReflection(
        id: 'r1',
        body: 'مساحة هادئة',
        mood: 'مطمئن',
      );
      await database.recordMood(id: 'm1', mood: 'مطمئن');
      await database.recordSession(
        id: 's1',
        kind: 'breathing',
        durationSeconds: 180,
      );

      final summary = await repository.loadSummary();
      expect(summary.sessions, 1);
      expect(summary.journalEntries, 1);
      expect(summary.latestJournal, 'مساحة هادئة');
      expect(summary.latestMood, 'مطمئن');
    },
  );

  test('exports and imports data transactionally', () async {
    await database.saveReflection(id: 'r1', body: 'نسخة أولى', mood: 'هادئ');
    final snapshot = await repository.exportData();

    final targetPath =
        '/tmp/sukoon-target-${DateTime.now().microsecondsSinceEpoch}.db';
    final raw = await databaseFactoryFfi.openDatabase(targetPath);
    final target = await AppDatabase.forTesting(raw);
    await LocalRepository(target).importData(snapshot);
    final restored = await LocalRepository(target).loadSummary();

    expect(restored.journalEntries, 1);
    expect(restored.latestJournal, 'نسخة أولى');
    await target.close();
    await databaseFactoryFfi.deleteDatabase(targetPath);
  });

  test('stores sensitive fields sealed while returning cleartext through repository', () async {
    final targetPath =
        '/tmp/sukoon-encrypted-${DateTime.now().microsecondsSinceEpoch}.db';
    final raw = await databaseFactoryFfi.openDatabase(targetPath);
    final encrypted = await AppDatabase.forTesting(
      raw,
      codec: SensitiveFieldCodec(List<int>.generate(32, (index) => index)),
    );
    await encrypted.saveReflection(
      id: 'secret',
      body: 'نص لا يجب أن يظهر',
      mood: 'هادئ',
    );
    await encrypted.recordMood(
      id: 'mood-secret',
      mood: 'حساس',
      note: 'ملاحظة حساسة',
    );
    final rawRows = await raw.query('reflection_entries');
    final rawMoodRows = await raw.query('mood_checkins');
    expect(rawRows.single['body'], isEmpty);
    expect(rawMoodRows.single['mood'], isEmpty);
    expect(rawMoodRows.single['note'], isEmpty);
    expect(rawRows.single['body_sealed'], isNot(contains('نص لا يجب أن يظهر')));
    expect((await encrypted.latestReflection())!['body'], 'نص لا يجب أن يظهر');
    expect((await encrypted.latestMood())!['mood'], 'حساس');
    await encrypted.close();
    await databaseFactoryFfi.deleteDatabase(targetPath);
  });

  test(
    'migrates a v1 database and decrypts legacy rows through the repository',
    () async {
      final path = await createLegacyDatabase();
      final upgraded = await AppDatabase.openAtPath(
        path,
        codec: SensitiveFieldCodec(
          List<int>.generate(32, (index) => index + 1),
        ),
      );
      final raw = await upgraded.db.query('reflection_entries');
      final rawMood = await upgraded.db.query('mood_checkins');
      expect(raw.single['body'], isEmpty);
      expect(rawMood.single['mood'], isEmpty);
      expect((await upgraded.latestReflection())!['body'], 'بيانات قديمة');
      expect((await upgraded.latestMood())!['note'], 'ملاحظة قديمة');
      await upgraded.close();
      await databaseFactoryFfi.deleteDatabase(path);
    },
  );

  test(
    'failed encryption migration does not leave a half-migrated database',
    () async {
      final path = await createLegacyDatabase();
      expect(
        () => AppDatabase.openAtPath(path, codec: _FailingCodec()),
        throwsA(anything),
      );
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1),
      );
      final row = await legacy.query('reflection_entries');
      expect(row.single['body'], 'بيانات قديمة');
      await legacy.close();
      await databaseFactoryFfi.deleteDatabase(path);
    },
  );

  test('deletes all user data transactionally', () async {
    await database.saveReflection(id: 'delete-r', body: 'حذف', mood: 'هادئ');
    await database.recordMood(id: 'delete-m', mood: 'هادئ', note: 'حذف');
    await database.recordSession(
      id: 'delete-s',
      kind: 'focus',
      durationSeconds: 60,
    );

    await repository.deleteAllData();
    final summary = await repository.loadSummary();
    expect(summary.sessions, 0);
    expect(summary.journalEntries, 0);
    expect(summary.moodCheckins, 0);
    expect(summary.latestJournal, isNull);
    expect(summary.latestMood, isNull);
  });

  test('supports soft-delete, restore, and final purge', () async {
    await database.saveReflection(
      id: 'soft-r',
      body: 'قابل للاستعادة',
      mood: 'هادئ',
    );
    await repository.softDeleteReflection('soft-r');
    expect((await repository.loadSummary()).journalEntries, 0);

    await repository.restoreReflection('soft-r');
    expect((await repository.loadSummary()).latestJournal, 'قابل للاستعادة');

    await repository.softDeleteReflection('soft-r');
    await repository.purgeDeletedData();
    expect((await repository.loadSummary()).journalEntries, 0);
  });
}

class _FailingCodec extends SensitiveFieldCodec {
  _FailingCodec() : super(List<int>.filled(32, 7));

  @override
  Future<String> seal(String value) => throw StateError('simulated failure');
}
