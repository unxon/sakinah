import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../data/local_repository.dart';
import 'backup_codec.dart';

class BackupService {
  BackupService(this.repository);
  final LocalRepository repository;
  static const maxBackupBytes = 25 * 1024 * 1024;
  static const maxRowsPerCollection = 10000;

  Future<String?> exportBackup(String passphrase) async {
    final snapshot = await repository.exportData();
    final encoded = await BackupCodec.encrypt(snapshot, passphrase);
    if (utf8.encode(encoded).length > maxBackupBytes) {
      throw const FormatException('Backup is too large');
    }
    return FilePicker.platform.saveFile(
      dialogTitle: 'حفظ نسخة سكون المشفرة',
      fileName:
          'sukoon-backup-${DateTime.now().toUtc().millisecondsSinceEpoch}.sukoon',
      bytes: Uint8List.fromList(utf8.encode(encoded)),
    );
  }

  Future<BackupPreview?> previewRestore(String passphrase) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختيار نسخة سكون',
      type: FileType.custom,
      allowedExtensions: ['sukoon'],
      withData: true,
    );
    if (result == null ||
        (result.files.single.bytes == null &&
            result.files.single.path == null)) {
      return null;
    }
    final file = result.files.single;
    final size = file.size;
    if (size > maxBackupBytes) {
      throw const FormatException('Backup is too large');
    }
    final encoded = file.bytes != null
        ? String.fromCharCodes(file.bytes!)
        : await File(file.path!).readAsString();
    final snapshot = await BackupCodec.decrypt(encoded, passphrase);
    _validateSnapshotLimits(snapshot);
    return BackupPreview(snapshot: snapshot, encodedSize: encoded.length);
  }

  static void _validateSnapshotLimits(Map<String, dynamic> snapshot) {
    for (final key in const [
      'reflection_entries',
      'session_records',
      'mood_checkins',
    ]) {
      final rows = snapshot[key];
      if (rows is! List || rows.length > maxRowsPerCollection) {
        throw const FormatException('Backup contains too many records');
      }
    }
  }

  Future<void> restore(BackupPreview preview) =>
      repository.importData(preview.snapshot);
}

class BackupPreview {
  const BackupPreview({required this.snapshot, required this.encodedSize});
  final Map<String, dynamic> snapshot;
  final int encodedSize;

  int get reflections =>
      (snapshot['reflection_entries'] as List? ?? const []).length;
  int get sessions => (snapshot['session_records'] as List? ?? const []).length;
  int get moods => (snapshot['mood_checkins'] as List? ?? const []).length;
}
