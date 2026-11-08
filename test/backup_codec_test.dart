import 'package:flutter_test/flutter_test.dart';
import 'package:serenity_reflection/security/backup_codec.dart';

void main() {
  const snapshot = {
    'schema_version': 1,
    'reflection_entries': [
      {'id': 'entry-1', 'body': 'نص خاص', 'mood': 'هادئ'},
    ],
    'session_records': [],
    'mood_checkins': [],
  };

  test('encrypts and restores a backup round-trip', () async {
    final encoded = await BackupCodec.encrypt(
      snapshot,
      'عبارة مرور آمنة جدًا 2026',
    );
    final restored = await BackupCodec.decrypt(
      encoded,
      'عبارة مرور آمنة جدًا 2026',
    );
    expect(restored['schema_version'], 1);
    expect((restored['reflection_entries'] as List).single['body'], 'نص خاص');
  });

  test('rejects a tampered backup', () async {
    final encoded = await BackupCodec.encrypt(
      snapshot,
      'عبارة مرور آمنة جدًا 2026',
    );
    final tampered = encoded.replaceFirst('ciphertext', 'ciphertext_changed');
    expect(
      () => BackupCodec.decrypt(tampered, 'عبارة مرور آمنة جدًا 2026'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a weak passphrase', () async {
    expect(
      () => BackupCodec.encrypt(snapshot, 'short'),
      throwsA(isA<FormatException>()),
    );
  });
}
