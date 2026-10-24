import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/secure_storage_helper.dart';

class RecentFile {
  final String path;
  final bool isCloud;
  final String? remotePath;
  final String? webDavProfileId;
  final String? lastSyncedETag;
  final DateTime? lastSyncedMTime;
  final bool pendingUpload;

  const RecentFile({
    required this.path,
    this.isCloud = false,
    this.remotePath,
    this.webDavProfileId,
    this.lastSyncedETag,
    this.lastSyncedMTime,
    this.pendingUpload = false,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'isCloud': isCloud,
    if (remotePath != null) 'remotePath': remotePath,
    if (webDavProfileId != null) 'webDavProfileId': webDavProfileId,
    if (lastSyncedETag != null) 'lastSyncedETag': lastSyncedETag,
    if (lastSyncedMTime != null)
      'lastSyncedMTime': lastSyncedMTime!.toIso8601String(),
    if (pendingUpload) 'pendingUpload': true,
  };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
    path: json['path'] as String? ?? '',
    isCloud: json['isCloud'] as bool? ?? false,
    remotePath: json['remotePath'] as String?,
    webDavProfileId: json['webDavProfileId'] as String?,
    lastSyncedETag: json['lastSyncedETag'] as String?,
    lastSyncedMTime: json['lastSyncedMTime'] is String
        ? DateTime.tryParse(json['lastSyncedMTime'] as String)
        : null,
    pendingUpload: json['pendingUpload'] == true,
  );
}

class RecentFilesService {
  static const _key = 'recent_files';
  static const _lastOpenedKey = 'last_opened_file';
  // Crash-safety snapshot: written with the previous generation before the
  // main key is overwritten. flutter_secure_storage has no atomic replace,
  // and on Windows all values live in one DPAPI file — an interrupted write
  // would otherwise corrupt the only copy, losing every record including the
  // pendingUpload markers and last-synced ETags that guard cloud uploads.
  static const _backupKey = 'recent_files_backup';
  final _storage = const SecureStorageHelper();

  /// Serializes read-modify-write cycles across instances. Concurrent
  /// metadata updates (e.g. an auto-save upload finishing while the user
  /// locks the database) would otherwise overwrite each other and could drop
  /// the pendingUpload marker, leaving local and cloud silently diverged.
  static Future<void> _writeQueue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    // Keep the chain alive even when an action fails.
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<RecentFile>> getRecentFiles() async {
    return await _readStoredList() ?? [];
  }

  /// Reads the list, falling back to the previous generation when the main
  /// payload is missing or unreadable (crash mid-write / DPAPI corruption).
  Future<List<RecentFile>?> _readStoredList() async {
    for (final key in [_key, _backupKey]) {
      final data = await _storage.read(key: key);
      if (data == null) continue;
      try {
        final list = jsonDecode(data) as List;
        return list.map((e) {
          if (e is String) return RecentFile(path: e);
          return RecentFile.fromJson(e as Map<String, dynamic>);
        }).toList();
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Writes [files] with a rollback copy: the current payload is preserved
  /// under the backup key before the main key is replaced.
  Future<void> _writeStoredList(List<RecentFile> files) async {
    final current = await _storage.read(key: _key);
    if (current != null) {
      await _storage.write(key: _backupKey, value: current);
    }
    await _storage.write(
      key: _key,
      value: jsonEncode(files.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> addRecentFile(
    String filePath, {
    bool isCloud = false,
    String? remotePath,
    String? webDavProfileId,
    String? lastSyncedETag,
    DateTime? lastSyncedMTime,
    bool pendingUpload = false,
  }) {
    return _serialized(() async {
      final files = await getRecentFiles();
      files.removeWhere((f) => f.path == filePath);
      files.insert(
        0,
        RecentFile(
          path: filePath,
          isCloud: isCloud,
          remotePath: remotePath,
          webDavProfileId: webDavProfileId,
          lastSyncedETag: lastSyncedETag,
          lastSyncedMTime: lastSyncedMTime,
          pendingUpload: pendingUpload,
        ),
      );
      if (files.length > AppConstants.maxRecentFiles) {
        files.removeRange(AppConstants.maxRecentFiles, files.length);
      }
      await _writeStoredList(files);
    });
  }

  Future<void> removeRecentFile(String filePath) {
    return _serialized(() async {
      final files = await getRecentFiles();
      files.removeWhere((f) => f.path == filePath);
      await _writeStoredList(files);
    });
  }

  Future<RecentFile?> getLastOpenedFile() async {
    final data = await _storage.read(key: _lastOpenedKey);
    if (data == null) return null;
    try {
      return RecentFile.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastOpenedFile(
    String filePath, {
    bool isCloud = false,
    String? remotePath,
    String? webDavProfileId,
    String? lastSyncedETag,
    DateTime? lastSyncedMTime,
    bool pendingUpload = false,
  }) {
    return _serialized(() async {
      await _storage.write(
        key: _lastOpenedKey,
        value: jsonEncode(
          RecentFile(
            path: filePath,
            isCloud: isCloud,
            remotePath: remotePath,
            webDavProfileId: webDavProfileId,
            lastSyncedETag: lastSyncedETag,
            lastSyncedMTime: lastSyncedMTime,
            pendingUpload: pendingUpload,
          ).toJson(),
        ),
      );
    });
  }

  Future<void> clearLastOpenedFile() async {
    await _storage.delete(key: _lastOpenedKey);
  }
}
