import '../entities/devotion.dart';

abstract interface class DevotionRepository {
  Future<List<Devotion>> list({String? query, String? packageId});
  Future<Devotion?> byId(String id);
  Future<void> installPackage(String packageJson);
  Future<void> removePackage(String packageId);
}
