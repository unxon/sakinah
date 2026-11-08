import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class BackupCodec {
  static const format = 'sukoon-backup-v1';
  static const iterations = 120000;
  static final _kdf = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
  static final _cipher = AesGcm.with256bits();

  static Future<String> encrypt(
    Map<String, dynamic> snapshot,
    String passphrase,
  ) async {
    _validatePassphrase(passphrase);
    final salt = _randomBytes(16);
    final key = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final plain = utf8.encode(jsonEncode(snapshot));
    final box = await _cipher.encrypt(plain, secretKey: key);
    return jsonEncode({
      'format': format,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64UrlEncode(salt),
      'nonce': base64UrlEncode(box.nonce),
      'mac': base64UrlEncode(box.mac.bytes),
      'ciphertext': base64UrlEncode(box.cipherText),
    });
  }

  static Future<Map<String, dynamic>> decrypt(
    String encoded,
    String passphrase,
  ) async {
    _validatePassphrase(passphrase);
    final envelope = _readEnvelope(encoded);
    final salt = _bytes(envelope['salt']);
    final nonce = _bytes(envelope['nonce']);
    final mac = Mac(_bytes(envelope['mac']));
    final cipherText = _bytes(envelope['ciphertext']);
    final key = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
    final clear = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
    );
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map) throw const FormatException('Invalid backup payload');
    return Map<String, dynamic>.from(decoded);
  }

  static Map<String, dynamic> _readEnvelope(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map ||
          value['format'] != format ||
          value['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          value['cipher'] != 'AES-256-GCM' ||
          value['iterations'] != iterations) {
        throw const FormatException('Unsupported backup format');
      }
      for (final key in ['salt', 'nonce', 'mac', 'ciphertext']) {
        if (value[key] is! String || (value[key] as String).isEmpty) {
          throw const FormatException('Incomplete backup envelope');
        }
      }
      return Map<String, dynamic>.from(value);
    } catch (error) {
      if (error is FormatException) {
        rethrow;
      }
      throw const FormatException('Invalid backup file');
    }
  }

  static List<int> _bytes(dynamic value) {
    try {
      final bytes = base64Url.decode(value as String);
      if (bytes.isEmpty) throw const FormatException('Empty backup field');
      return bytes;
    } catch (_) {
      throw const FormatException('Invalid backup encoding');
    }
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static void _validatePassphrase(String value) {
    if (value.trim().length < 12) {
      throw const FormatException('Passphrase must be at least 12 characters');
    }
  }
}
