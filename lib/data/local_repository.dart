import 'app_database.dart';

class LocalRepository {
  LocalRepository(this.database);
  final AppDatabase database;

  Future<LocalSummary> loadSummary() async {
    final snapshot = await database.exportSnapshot();
    final latestReflection = await database.latestReflection();
    final latestMood = await database.latestMood();
    return LocalSummary(
      sessions: (snapshot['session_records'] as List).length,
      journalEntries: (snapshot['reflection_entries'] as List).length,
      moodCheckins: (snapshot['mood_checkins'] as List).length,
      latestJournal: latestReflection?['body'] as String?,
      latestMood: latestMood?['mood'] as String?,
    );
  }

  Future<Map<String, dynamic>> exportData() => database.exportSnapshot();

  Future<void> importData(Map<String, dynamic> snapshot) =>
      database.importSnapshot(snapshot);

  Future<void> deleteAllData() => database.deleteAllData();

  Future<void> softDeleteReflection(String id) =>
      database.softDeleteReflection(id);

  Future<void> restoreReflection(String id) => database.restoreReflection(id);

  Future<void> purgeDeletedData() => database.purgeDeletedData();
}

class LocalSummary {
  const LocalSummary({
    required this.sessions,
    required this.journalEntries,
    required this.moodCheckins,
    this.latestJournal,
    this.latestMood,
  });
  final int sessions;
  final int journalEntries;
  final int moodCheckins;
  final String? latestJournal;
  final String? latestMood;
}
