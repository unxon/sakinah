import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalSnapshot {
  final Set<String> favorites;
  final Map<String, int> counts;
  final List<Map<String, String>> personal;
  final List<Map<String, String>> plans;
  final Map<String, String> settings;

  const LocalSnapshot({
    required this.favorites,
    required this.counts,
    required this.personal,
    required this.plans,
    required this.settings,
  });
}

class LocalStore {
  final bool memoryOnly;
  Database? _db;
  final Set<String> _memoryFavorites = {'morning-001'};
  final Map<String, int> _memoryCounts = {'morning-001': 3};
  final List<Map<String, String>> _memoryPersonal = [];
  final List<Map<String, String>> _memoryPlans = [
    {
      'id': 'morning-plan',
      'title': 'ورد الصباح',
      'subtitle': 'أذكار الصباح · كل يوم',
      'progress': '0.68',
      'active': '1'
    },
    {
      'id': 'gratitude-plan',
      'title': 'لحظة امتنان',
      'subtitle': 'دعاء قصير · كل مساء',
      'progress': '0.32',
      'active': '1'
    },
  ];
  final Map<String, String> _memorySettings = {
    'darkMode': '0',
    'showSources': '1',
    'fontScale': '1.0',
    'reducedMotion': '0',
  };

  LocalStore({this.memoryOnly = false});
  LocalStore.inMemory() : memoryOnly = true;

  Future<void> open() async {
    if (memoryOnly) return;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      join(root, 'sakeena.db'),
      version: 3,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE personal_texts ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)');
        }
        if (oldVersion < 3) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS plans (id TEXT PRIMARY KEY, title TEXT NOT NULL, subtitle TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
          await _seedDefaults(db);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute(
        'CREATE TABLE favorites (item_id TEXT PRIMARY KEY, created_at INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE counter_events (id TEXT PRIMARY KEY, item_id TEXT NOT NULL, count INTEGER NOT NULL, occurred_at INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE personal_texts (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE plans (id TEXT PRIMARY KEY, title TEXT NOT NULL, subtitle TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
  }

  Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final plans = [
      {
        'id': 'morning-plan',
        'title': 'ورد الصباح',
        'subtitle': 'أذكار الصباح · كل يوم',
        'progress': 0.68,
        'active': 1,
        'created_at': now,
        'updated_at': now
      },
      {
        'id': 'gratitude-plan',
        'title': 'لحظة امتنان',
        'subtitle': 'دعاء قصير · كل مساء',
        'progress': 0.32,
        'active': 1,
        'created_at': now,
        'updated_at': now
      },
    ];
    for (final plan in plans) {
      await db.insert('plans', plan,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final entry in _memorySettings.entries) {
      await db.insert('settings',
          {'key': entry.key, 'value': entry.value, 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<LocalSnapshot> load() async {
    if (memoryOnly || _db == null) {
      return LocalSnapshot(
        favorites: {..._memoryFavorites},
        counts: {..._memoryCounts},
        personal: [..._memoryPersonal],
        plans: [..._memoryPlans],
        settings: {..._memorySettings},
      );
    }
    final favorites = (await _db!.query('favorites'))
        .map((row) => row['item_id']! as String)
        .toSet();
    final events = await _db!.query('counter_events');
    final counts = <String, int>{};
    for (final row in events) {
      final id = row['item_id']! as String;
      counts[id] = (counts[id] ?? 0) + (row['count']! as int);
    }
    final personal =
        (await _db!.query('personal_texts', orderBy: 'updated_at DESC'))
            .map((row) => {
                  'id': '${row['id']}',
                  'title': row['title']! as String,
                  'body': row['body']! as String
                })
            .toList();
    final plans = (await _db!
            .query('plans', where: 'active = 1', orderBy: 'updated_at DESC'))
        .map((row) => {
              'id': row['id']! as String,
              'title': row['title']! as String,
              'subtitle': row['subtitle']! as String,
              'progress': '${row['progress']}',
              'active': '${row['active']}'
            })
        .toList();
    final settings = <String, String>{};
    for (final row in await _db!.query('settings')) {
      settings[row['key']! as String] = row['value']! as String;
    }
    return LocalSnapshot(
        favorites: favorites,
        counts: counts,
        personal: personal,
        plans: plans,
        settings: settings);
  }

  Future<void> setFavorite(String itemId, bool value) async {
    if (memoryOnly || _db == null) {
      if (value) {
        _memoryFavorites.add(itemId);
      } else {
        _memoryFavorites.remove(itemId);
      }
      return;
    }
    if (value) {
      await _db!.insert(
          'favorites',
          {
            'item_id': itemId,
            'created_at': DateTime.now().millisecondsSinceEpoch
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await _db!.delete('favorites', where: 'item_id = ?', whereArgs: [itemId]);
    }
  }

  Future<void> addCount(String itemId) async {
    if (memoryOnly || _db == null) {
      _memoryCounts[itemId] = (_memoryCounts[itemId] ?? 0) + 1;
      return;
    }
    await _db!.insert('counter_events', {
      'id': '$itemId-${DateTime.now().microsecondsSinceEpoch}',
      'item_id': itemId,
      'count': 1,
      'occurred_at': DateTime.now().millisecondsSinceEpoch
    });
  }

  Future<String> addPersonal(String title, String body) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (memoryOnly || _db == null) {
      final id = '$now-${_memoryPersonal.length}';
      _memoryPersonal.insert(0, {'id': id, 'title': title, 'body': body});
      return id;
    }
    final id = await _db!.insert('personal_texts',
        {'title': title, 'body': body, 'created_at': now, 'updated_at': now});
    return '$id';
  }

  Future<void> updatePersonal(String id, String title, String body) async {
    if (memoryOnly || _db == null) {
      final index = _memoryPersonal.indexWhere((item) => item['id'] == id);
      if (index >= 0) {
        _memoryPersonal[index] = {'id': id, 'title': title, 'body': body};
      }
      return;
    }
    await _db!.update(
        'personal_texts',
        {
          'title': title,
          'body': body,
          'updated_at': DateTime.now().millisecondsSinceEpoch
        },
        where: 'id = ?',
        whereArgs: [int.tryParse(id) ?? -1]);
  }

  Future<void> deletePersonal(String id) async {
    if (memoryOnly || _db == null) {
      _memoryPersonal.removeWhere((item) => item['id'] == id);
      return;
    }
    await _db!.delete('personal_texts',
        where: 'id = ?', whereArgs: [int.tryParse(id) ?? -1]);
  }

  Future<String> addPlan(String title, String subtitle) async {
    final id = 'plan-${DateTime.now().microsecondsSinceEpoch}';
    if (memoryOnly || _db == null) {
      _memoryPlans.insert(0, {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'progress': '0',
        'active': '1'
      });
      return id;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db!.insert('plans', {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'progress': 0.0,
      'active': 1,
      'created_at': now,
      'updated_at': now
    });
    return id;
  }

  Future<void> deletePlan(String id) async {
    if (memoryOnly || _db == null) {
      _memoryPlans.removeWhere((item) => item['id'] == id);
      return;
    }
    await _db!.update('plans',
        {'active': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setSetting(String key, String value) async {
    if (memoryOnly || _db == null) {
      _memorySettings[key] = value;
      return;
    }
    await _db!.insert(
        'settings',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().millisecondsSinceEpoch
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
