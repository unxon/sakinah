import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/devotion.dart';
import '../../domain/repositories/devotion_repository.dart';

class AssetDevotionRepository implements DevotionRepository {
  final String assetPath;
  const AssetDevotionRepository(
      {this.assetPath = 'assets/content/packages/core-ar.json'});

  @override
  Future<List<Devotion>> list({String? query, String? packageId}) async {
    final raw = await rootBundle.loadString(assetPath);
    final items = (jsonDecode(raw)['items'] as List)
        .cast<Map<String, dynamic>>()
        .map(Devotion.fromJson)
        .where((item) => packageId == null || item.packageId == packageId)
        .where((item) =>
            query == null || '${item.title}${item.body}'.contains(query))
        .toList();
    return items;
  }

  @override
  Future<Devotion?> byId(String id) async {
    final items = await list();
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> installPackage(String packageJson) async {
    throw UnsupportedError(
        'Package installation belongs to the local data layer.');
  }

  @override
  Future<void> removePackage(String packageId) async {
    throw UnsupportedError('Package removal belongs to the local data layer.');
  }
}
