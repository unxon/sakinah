import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureVault {
  SecureVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _backupKey = 'sukoon_backup_key_v1';
  static const _dataKey = 'sukoon_data_key_v1';

  Future<String> ensureBackupKey() async {
    final existing = await _storage.read(key: _backupKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final value = base64UrlEncode(bytes);
    await _storage.write(key: _backupKey, value: value);
    return value;
  }

  Future<String> ensureDataKey() async {
    final existing = await readDataKey();
    if (existing != null) return existing;
    return createDataKey();
  }

  Future<String?> readDataKey() async {
    final existing = await _storage.read(key: _dataKey);
    return existing == null || existing.isEmpty ? null : existing;
  }

  Future<String> createDataKey() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final value = base64UrlEncode(bytes);
    await _storage.write(key: _dataKey, value: value);
    return value;
  }

  Future<void> deleteBackupKey() => _storage.delete(key: _backupKey);
}
