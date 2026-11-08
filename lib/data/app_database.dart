import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../security/sensitive_field_codec.dart';

class AppDatabase {
  AppDatabase._(this.db, this.codec);
  AppDatabase.fromDatabase(this.db, {this.codec});
  final Database db;
  final SensitiveFieldCodec? codec;

  static Future<AppDatabase> forTesting(
    Database database, {
    SensitiveFieldCodec? codec,
  }) async {
    await _createSchema(database);
    return AppDatabase._(database, codec);
  }

  static Future<AppDatabase> open({SensitiveFieldCodec? codec}) async {
    final root = await getDatabasesPath();
    return openAtPath(path.join(root, 'sukoon.db'), codec: codec);
  }

  static Future<AppDatabase> openAtPath(
    String databasePath, {
    SensitiveFieldCodec? codec,
  }) async {
    final database = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrate(db, oldVersion, newVersion, codec);
      },
    );
    return AppDatabase._(database, codec);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE reflection_entries (
        id TEXT PRIMARY KEY,
        body TEXT NOT NULL,
        mood TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        body_sealed TEXT,
        mood_sealed TEXT,
        encrypted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE session_records (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        completed_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE mood_checkins (
        id TEXT PRIMARY KEY,
        mood TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        mood_sealed TEXT,
        note_sealed TEXT,
        encrypted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_reflection_updated ON reflection_entries(updated_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sessions_completed ON session_records(completed_at)',
    );
  }

  static Future<void> _migrate(
    Database db,
    int from,
    int to,
    SensitiveFieldCodec? codec,
  ) async {
    // Forward-only migrations. Destructive changes require a preflight backup.
    if (from < 2 && to >= 2) {
      await db.execute(
        'ALTER TABLE reflection_entries ADD COLUMN body_sealed TEXT',
      );
      await db.execute(
        'ALTER TABLE reflection_entries ADD COLUMN mood_sealed TEXT',
      );
      await db.execute(
        'ALTER TABLE reflection_entries ADD COLUMN encrypted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE mood_checkins ADD COLUMN note_sealed TEXT');
      await db.execute('ALTER TABLE mood_checkins ADD COLUMN mood_sealed TEXT');
      await db.execute(
        'ALTER TABLE mood_checkins ADD COLUMN encrypted INTEGER NOT NULL DEFAULT 0',
      );
      if (codec != null) await _encryptLegacyRows(db, codec);
    }
  }

  static Future<void> _encryptLegacyRows(
    Database db,
    SensitiveFieldCodec codec,
  ) async {
    final reflections = await db.query(
      'reflection_entries',
      where: 'encrypted = 0',
    );
    for (final row in reflections) {
      await db.update(
        'reflection_entries',
        {
          'body_sealed': await codec.seal(row['body'] as String),
          'mood_sealed': await codec.seal(row['mood'] as String),
          'body': '',
          'mood': '',
          'encrypted': 1,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    final moods = await db.query('mood_checkins', where: 'encrypted = 0');
    for (final row in moods) {
      await db.update(
        'mood_checkins',
        {
          'mood_sealed': await codec.seal(row['mood'] as String),
          'note_sealed': await codec.seal(row['note'] as String),
          'mood': '',
          'note': '',
          'encrypted': 1,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> saveReflection({
    required String id,
    required String body,
    required String mood,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final sealedBody = codec == null ? null : await codec!.seal(body);
    final sealedMood = codec == null ? null : await codec!.seal(mood);
    await db.insert('reflection_entries', {
      'id': id,
      'body': sealedBody == null ? body : '',
      'mood': sealedMood == null ? mood : '',
      'created_at': now,
      'updated_at': now,
      'body_sealed': sealedBody,
      'mood_sealed': sealedMood,
      'encrypted': codec == null ? 0 : 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> recordSession({
    required String id,
    required String kind,
    required int durationSeconds,
  }) async {
    await db.insert('session_records', {
      'id': id,
      'kind': kind,
      'duration_seconds': durationSeconds,
      'completed_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> recordMood({
    required String id,
    required String mood,
    String note = '',
  }) async {
    final sealedMood = codec == null ? null : await codec!.seal(mood);
    final sealedNote = codec == null ? null : await codec!.seal(note);
    await db.insert('mood_checkins', {
      'id': id,
      'mood': sealedMood == null ? mood : '',
      'note': sealedNote == null ? note : '',
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'mood_sealed': sealedMood,
      'note_sealed': sealedNote,
      'encrypted': codec == null ? 0 : 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> countCompletedSessions() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM session_records',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> hasEncryptedData() async {
    final reflection = await db.query(
      'reflection_entries',
      columns: const ['id'],
      where: 'encrypted = 1',
      limit: 1,
    );
    if (reflection.isNotEmpty) return true;
    final moods = await db.query(
      'mood_checkins',
      columns: const ['id'],
      where: 'encrypted = 1',
      limit: 1,
    );
    return moods.isNotEmpty;
  }

  Future<void> deleteAllData() async {
    await db.transaction((txn) async {
      await txn.delete('reflection_entries');
      await txn.delete('session_records');
      await txn.delete('mood_checkins');
    });
  }

  Future<void> softDeleteReflection(String id) async {
    await db.update(
      'reflection_entries',
      {'deleted_at': DateTime.now().toUtc().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreReflection(String id) async {
    await db.update(
      'reflection_entries',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> purgeDeletedData() async {
    await db.delete('reflection_entries', where: 'deleted_at IS NOT NULL');
  }

  Future<Map<String, dynamic>?> latestReflection() async {
    final rows = await db.query(
      'reflection_entries',
      orderBy: 'updated_at DESC',
      limit: 1,
      where: 'deleted_at IS NULL',
    );
    return rows.isEmpty ? null : await _decodeReflectionAsync(rows.first);
  }

  Future<Map<String, dynamic>?> latestMood() async {
    final rows = await db.query(
      'mood_checkins',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : await _decodeMoodAsync(rows.first);
  }

  Future<Map<String, dynamic>> exportSnapshot() async {
    final reflectionRows = await db.query(
      'reflection_entries',
      orderBy: 'updated_at ASC',
      where: 'deleted_at IS NULL',
    );
    final sessions = await db.query(
      'session_records',
      orderBy: 'completed_at ASC',
    );
    final moodRows = await db.query('mood_checkins', orderBy: 'created_at ASC');
    final reflections = <Map<String, dynamic>>[];
    for (final row in reflectionRows) {
      reflections.add(await _decodeReflectionAsync(row));
    }
    final moods = <Map<String, dynamic>>[];
    for (final row in moodRows) {
      moods.add(await _decodeMoodAsync(row));
    }
    return {
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'reflection_entries': reflections,
      'session_records': sessions,
      'mood_checkins': moods,
    };
  }

  Future<Map<String, dynamic>> _decodeReflectionAsync(
    Map<String, dynamic> row,
  ) async {
    if (row['encrypted'] != 1 || codec == null) return row;
    final copy = Map<String, dynamic>.from(row);
    copy['body'] = await codec!.open(row['body_sealed'] as String);
    copy['mood'] = await codec!.open(row['mood_sealed'] as String);
    copy.remove('body_sealed');
    copy.remove('mood_sealed');
    copy['encrypted'] = 0;
    return copy;
  }

  Future<Map<String, dynamic>> _decodeMoodAsync(
    Map<String, dynamic> row,
  ) async {
    if (row['encrypted'] != 1 || codec == null) return row;
    final copy = Map<String, dynamic>.from(row);
    copy['mood'] = await codec!.open(row['mood_sealed'] as String);
    copy['note'] = await codec!.open(row['note_sealed'] as String);
    copy.remove('mood_sealed');
    copy.remove('note_sealed');
    copy['encrypted'] = 0;
    return copy;
  }

  Future<void> importSnapshot(Map<String, dynamic> snapshot) async {
    if (snapshot['schema_version'] != 1) {
      throw FormatException('Unsupported backup schema');
    }
    final reflections = _maps(snapshot['reflection_entries']);
    final sessions = _maps(snapshot['session_records']);
    final moods = _maps(snapshot['mood_checkins']);
    await db.transaction((txn) async {
      for (final row in reflections) {
        final protectedRow = await _protectReflectionRow(row);
        await txn.insert(
          'reflection_entries',
          protectedRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in sessions) {
        await txn.insert(
          'session_records',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final row in moods) {
        final protectedRow = await _protectMoodRow(row);
        await txn.insert(
          'mood_checkins',
          protectedRow,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<Map<String, dynamic>> _protectReflectionRow(
    Map<String, dynamic> row,
  ) async {
    if (codec == null) return row;
    final copy = Map<String, dynamic>.from(row);
    copy['body_sealed'] = await codec!.seal(row['body'] as String? ?? '');
    copy['mood_sealed'] = await codec!.seal(row['mood'] as String? ?? '');
    copy['body'] = '';
    copy['mood'] = '';
    copy['encrypted'] = 1;
    return copy;
  }

  Future<Map<String, dynamic>> _protectMoodRow(Map<String, dynamic> row) async {
    if (codec == null) return row;
    final copy = Map<String, dynamic>.from(row);
    copy['mood_sealed'] = await codec!.seal(row['mood'] as String? ?? '');
    copy['note_sealed'] = await codec!.seal(row['note'] as String? ?? '');
    copy['mood'] = '';
    copy['note'] = '';
    copy['encrypted'] = 1;
    return copy;
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) {
      throw const FormatException('Invalid backup collection');
    }
    return value.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid backup row');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  Future<void> close() => db.close();
}
