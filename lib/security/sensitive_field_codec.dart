import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class SensitiveFieldCodec {
  SensitiveFieldCodec(this.keyBytes) : _cipher = AesGcm.with256bits();
  final List<int> keyBytes;
  final AesGcm _cipher;

  Future<String> seal(String value) async {
    final key = await _cipher.newSecretKeyFromBytes(keyBytes);
    final box = await _cipher.encrypt(utf8.encode(value), secretKey: key);
    return jsonEncode({
      'v': 1,
      'nonce': base64UrlEncode(box.nonce),
      'mac': base64UrlEncode(box.mac.bytes),
      'ciphertext': base64UrlEncode(box.cipherText),
    });
  }

  Future<String> open(String sealed) async {
    final value = jsonDecode(sealed);
    if (value is! Map || value['v'] != 1) {
      throw const FormatException('Unsupported encrypted field');
    }
    final box = SecretBox(
      _decode(value['ciphertext']),
      nonce: _decode(value['nonce']),
      mac: Mac(_decode(value['mac'])),
    );
    final key = await _cipher.newSecretKeyFromBytes(keyBytes);
    final clear = await _cipher.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }

  static List<int> _decode(dynamic value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Invalid encrypted field');
    }
    try {
      return base64Url.decode(value);
    } catch (_) {
      throw const FormatException('Invalid encrypted field encoding');
    }
  }
}
