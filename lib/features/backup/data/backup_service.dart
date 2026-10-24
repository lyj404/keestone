import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/logger.dart';

enum BackupIntegrityStatus { valid, legacy, missing, invalid, corrupted }

/// Last path segment regardless of separator style; recent-file records can
/// mix `\` and `/` (paths written on other platforms or older builds).
String _baseName(String path) =>
    path.split(Platform.pathSeparator).last.split('/').last;

class BackupVerificationResult {
  final BackupIntegrityStatus status;
  final Uint8List? bytes;
  const BackupVerificationResult(this.status, this.bytes);

  bool get canRestore =>
      status == BackupIntegrityStatus.valid ||
      status == BackupIntegrityStatus.legacy;
}

class BackupInfo {
  final String filename;
  final DateTime timestamp;
  final int sizeBytes;
  final String? sourcePath;

  BackupInfo({
    required this.filename,
    required this.timestamp,
    required this.sizeBytes,
    this.sourcePath,
  });
}

class BackupService {
  static const _retentionKey = 'backup_retention_count';
  static const _autoBackupKey = 'backup_auto_enabled';
  static const _defaultRetention = 5;
  final _storage = const SecureStorageHelper();
  final Directory? _backupDirectory;

  BackupService({this._backupDirectory});

  Future<bool> isAutoBackupEnabled() async {
    final val = await _storage.read(key: _autoBackupKey);
    return val == null || val == 'true';
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _storage.write(key: _autoBackupKey, value: enabled.toString());
  }

  Future<Directory> _backupDir() async {
    final appDir = _backupDirectory == null
        ? await getApplicationSupportDirectory()
        : null;
    final dir = _backupDirectory ?? Directory('${appDir!.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<int> getRetentionCount() async {
    final val = await _storage.read(key: _retentionKey);
    return val != null
        ? int.tryParse(val) ?? _defaultRetention
        : _defaultRetention;
  }

  Future<void> setRetentionCount(int count) async {
    await _storage.write(key: _retentionKey, value: count.toString());
  }

  Future<BackupInfo?> createBackup(String filePath) async {
    try {
      // Recent-file records can carry relative paths (e.g. a cloud cache
      // path stored on another platform). Backups must resolve them against
      // the documents directory instead of nesting them under the backup
      // folder, where the parent directories do not exist.
      var resolvedPath = filePath;
      if (!File(resolvedPath).existsSync()) {
        final docs = await getApplicationDocumentsDirectory();
        final candidate = File(
          filePath.startsWith('/')
              ? '${docs.path}$filePath'
              : '${docs.path}/$filePath',
        );
        if (candidate.existsSync()) {
          resolvedPath = candidate.path;
          log.i('Backup resolved relative source path: $resolvedPath');
        }
      }
      final file = File(resolvedPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final dir = await _backupDir();
      final now = DateTime.now();
      final ts =
          '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}_'
          '${now.millisecond.toString().padLeft(3, '0')}'
          '${now.microsecond.toString().padLeft(3, '0')}';
      final dbName = _baseName(resolvedPath).replaceAll('.kdbx', '');
      var filename = '${dbName}_$ts.kdbx';
      var backupFile = File('${dir.path}/$filename');
      var counter = 1;
      while (await backupFile.exists()) {
        filename = '${dbName}_${ts}_$counter.kdbx';
        backupFile = File('${dir.path}/$filename');
        counter++;
      }
      await backupFile.writeAsBytes(bytes, flush: true);
      final digest = await Sha256().hash(bytes);
      final sha256 = digest.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      await _writeMetadata(
        filename,
        sourcePath: filePath,
        sha256: sha256,
        sizeBytes: bytes.length,
        isPreOverwriteSnapshot: true,
      );
      log.i('Backup created: $filename (${bytes.length} bytes)');
      await _cleanupOldBackups(filePath);
      return BackupInfo(
        filename: filename,
        timestamp: now,
        sizeBytes: bytes.length,
        sourcePath: filePath,
      );
    } catch (e) {
      log.e('Backup failed: $e');
      return null;
    }
  }

  Future<List<BackupInfo>> listBackups() async {
    final dir = await _backupDir();
    final files = await dir
        .list()
        .where((f) => f.path.endsWith('.kdbx'))
        .toList();
    final backups = <BackupInfo>[];
    for (final f in files) {
      final stat = await f.stat();
      final name = f.path.split(Platform.pathSeparator).last;
      final sourcePath = await _readSourcePath(name);
      backups.add(
        BackupInfo(
          filename: name,
          timestamp: stat.modified,
          sizeBytes: stat.size,
          sourcePath: sourcePath,
        ),
      );
    }
    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return backups;
  }

  Future<List<BackupInfo>> listBackupsFor(String filePath) async {
    final fileName = _baseName(filePath);
    final backups = await listBackups();
    return backups.where((backup) {
      if (backup.sourcePath == filePath) return true;
      if (backup.sourcePath != null) return false;
      return backup.filename.startsWith('${fileName.replaceAll('.kdbx', '')}_');
    }).toList();
  }

  Future<String?> getBackupPath(String filename) async {
    final dir = await _backupDir();
    final file = File('${dir.path}/$filename');
    return await file.exists() ? file.path : null;
  }

  Future<BackupVerificationResult> verifyAndReadBackup(String filename) async {
    try {
      final path = await getBackupPath(filename);
      if (path == null) {
        return const BackupVerificationResult(
          BackupIntegrityStatus.missing,
          null,
        );
      }
      final bytes = await File(path).readAsBytes();
      final metaFile = await _metadataFile(filename);
      if (!await metaFile.exists()) {
        return BackupVerificationResult(BackupIntegrityStatus.legacy, bytes);
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(await metaFile.readAsString());
      } on FormatException {
        log.e('Backup metadata is not valid JSON');
        return const BackupVerificationResult(
          BackupIntegrityStatus.invalid,
          null,
        );
      }
      if (decoded is! Map<String, dynamic>) {
        return const BackupVerificationResult(
          BackupIntegrityStatus.invalid,
          null,
        );
      }
      final expectedSize = decoded['sizeBytes'];
      final expectedHash = decoded['sha256'];
      if (expectedSize == null || expectedHash == null) {
        return BackupVerificationResult(BackupIntegrityStatus.legacy, bytes);
      }
      if (expectedSize is! int ||
          expectedHash is! String ||
          expectedHash.length != 64) {
        return const BackupVerificationResult(
          BackupIntegrityStatus.invalid,
          null,
        );
      }
      if (bytes.length != expectedSize) {
        return const BackupVerificationResult(
          BackupIntegrityStatus.corrupted,
          null,
        );
      }
      final digest = await Sha256().hash(bytes);
      final actualHash = digest.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      if (actualHash.toLowerCase() != expectedHash.toLowerCase()) {
        return const BackupVerificationResult(
          BackupIntegrityStatus.corrupted,
          null,
        );
      }
      return BackupVerificationResult(BackupIntegrityStatus.valid, bytes);
    } catch (e, st) {
      log.e('Backup verification failed', error: e, stackTrace: st);
      return const BackupVerificationResult(
        BackupIntegrityStatus.invalid,
        null,
      );
    }
  }

  Future<bool> deleteBackup(String filename) async {
    try {
      final dir = await _backupDir();
      final file = File('${dir.path}/$filename');
      if (await file.exists()) {
        await file.delete();
        await _deleteMetadata(filename);
        log.i('Backup deleted: $filename');
        return true;
      }
      return false;
    } catch (e) {
      log.e('Delete backup failed: $e');
      return false;
    }
  }

  Future<void> _cleanupOldBackups(String filePath) async {
    final retention = await getRetentionCount();
    final backups = await listBackupsFor(filePath);
    if (backups.length <= retention) return;
    final toRemove = backups.sublist(retention);
    for (final b in toRemove) {
      await deleteBackup(b.filename);
    }
  }

  Future<void> _writeMetadata(
    String filename, {
    required String sourcePath,
    required String sha256,
    required int sizeBytes,
    bool isPreOverwriteSnapshot = false,
  }) async {
    final metaFile = await _metadataFile(filename);
    await metaFile.writeAsString(
      jsonEncode({
        'version': 2,
        'sourcePath': sourcePath,
        'sha256': sha256,
        'sizeBytes': sizeBytes,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        // Backups are taken before the atomic replace, so they hold the
        // *previous* version of the database (the rollback target), not the
        // newly saved one. Flag it so restore UIs can label it correctly.
        if (isPreOverwriteSnapshot) 'isPreOverwriteSnapshot': true,
      }),
      flush: true,
    );
  }

  Future<String?> _readSourcePath(String filename) async {
    final metaFile = await _metadataFile(filename);
    if (!await metaFile.exists()) return null;
    try {
      final data =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final sourcePath = data['sourcePath'];
      return sourcePath is String && sourcePath.isNotEmpty ? sourcePath : null;
    } catch (e) {
      log.w('Failed to read backup metadata for $filename: $e');
      return null;
    }
  }

  Future<void> _deleteMetadata(String filename) async {
    final metaFile = await _metadataFile(filename);
    if (await metaFile.exists()) {
      await metaFile.delete();
    }
  }

  Future<File> _metadataFile(String filename) async {
    final dir = await _backupDir();
    return File('${dir.path}/$filename.meta.json');
  }
}
