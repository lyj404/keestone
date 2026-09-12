import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/utils/logger.dart';
import '../data/csv_service.dart';
import '../data/database_service.dart';
import '../data/recent_files_service.dart';
export '../data/recent_files_service.dart' show RecentFile;
export '../data/csv_service.dart' show CsvEntry;
import '../../../core/providers/auto_lock_provider.dart';
import '../../../core/providers/auto_save_provider.dart';
import '../../../core/providers/expiration_reminder_provider.dart';
import '../../explorer/providers/explorer_provider.dart'
    show activeEntryProvider;
import '../../settings/data/webdav_config.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/data/sync_service.dart'
    show RemoteFileInfo, SyncErrorType, SyncException, normalizeETag;
import '../../sync/providers/sync_provider.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final csvServiceProvider = Provider<CsvService>((ref) {
  return CsvService();
});

final recentFilesServiceProvider = Provider<RecentFilesService>((ref) {
  return RecentFilesService();
});

final databaseProvider =
    StateNotifierProvider<DatabaseNotifier, AsyncValue<KdbxDatabase?>>((ref) {
      return DatabaseNotifier(ref);
    });

class DatabaseNotifier extends StateNotifier<AsyncValue<KdbxDatabase?>> {
  final Ref _ref;
  Object? _lastSyncError;
  String? _currentWebDavProfileId;
  SyncAuditReport? _lastSyncAuditReport;
  Future<bool>? _saveInFlight;
  int _session = 0;

  DatabaseNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _service.onDirtyChanged = (isDirty) {
      Future.microtask(() {
        _ref.read(isDirtyProvider.notifier).state = isDirty;
      });
    };
  }

  DatabaseService get _service => _ref.read(databaseServiceProvider);

  /// The last sync error, if any. Used by UI to show user-friendly messages.
  Object? get lastSyncError => _lastSyncError;
  SyncAuditReport? get lastSyncAuditReport => _lastSyncAuditReport;

  Future<void> preloadFile(String filePath) => _service.preloadFile(filePath);

  Future<void> openFile(
    String filePath,
    String password, {
    bool isCloud = false,
    String? webDavProfileId,
    String? syncedETag,
    Uint8List? keyData,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.openFile(filePath, password, keyData: keyData);
      String? remotePath;
      String? eTag = syncedETag;
      DateTime? remoteMTime;
      if (isCloud) {
        final config = await _ref
            .read(webDavSettingsServiceProvider)
            .getConfigById(webDavProfileId);
        if (config != null && config.enabled) {
          _currentWebDavProfileId = config.id;
          remotePath = config.remoteFilePath;
          if (syncedETag != null) {
            // Welcome screen already verified eTag, reuse it directly
            _service.setLastSyncedRemoteInfo(RemoteFileInfo(eTag: syncedETag));
          } else {
            RemoteFileInfo? info;
            try {
              info = await _ref
                  .read(syncServiceProvider)
                  .getRemoteFileInfo(config);
            } catch (e) {
              // Unreachable server must not block opening the database.
              // Leaving the remote info unset makes the first upload use
              // If-None-Match, which is fail-safe against overwriting a
              // remote file we never saw.
              log.w('Remote probe failed while opening database', error: e);
            }
            _service.setLastSyncedRemoteInfo(info);
            eTag = info?.eTag;
            remoteMTime = info?.mTime;
          }
        }
      } else {
        _currentWebDavProfileId = null;
      }
      _ref.read(openedFromCloudProvider.notifier).state = isCloud;
      if (!isCloud) {
        _currentWebDavProfileId = null;
      }
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
      unawaited(
        (() async {
          final recentSvc = _ref.read(recentFilesServiceProvider);
          await recentSvc.addRecentFile(
            filePath,
            isCloud: isCloud,
            remotePath: remotePath,
            webDavProfileId: _currentWebDavProfileId,
            lastSyncedETag: eTag,
            lastSyncedMTime: remoteMTime,
          );
          await recentSvc.setLastOpenedFile(
            filePath,
            isCloud: isCloud,
            remotePath: remotePath,
            webDavProfileId: _currentWebDavProfileId,
            lastSyncedETag: eTag,
            lastSyncedMTime: remoteMTime,
          );
        })().catchError((e, st) {
          log.w('Failed to update recent files after open: $e');
        }),
      );
      unawaited(_ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDatabase(
    String name,
    String password,
    String filePath, {
    Uint8List? keyData,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.createDatabase(
        name,
        password,
        filePath,
        keyData: keyData,
      );
      final recentSvc = _ref.read(recentFilesServiceProvider);

      // If WebDAV is enabled, link this new database to cloud so it syncs on save.
      final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
      final bool isCloud = config != null && config.enabled;
      String? remotePath;
      String? eTag;
      DateTime? remoteMTime;
      if (isCloud) {
        _currentWebDavProfileId = config.id;
        remotePath = config.remoteFilePath;
        _ref.read(openedFromCloudProvider.notifier).state = true;
        // Upload the newly created database to the cloud immediately. The
        // upload is conditional (If-None-Match: *) so an existing remote
        // database is never silently overwritten by a fresh local one.
        final syncService = _ref.read(syncServiceProvider);
        try {
          await syncService.ensureRemoteDirectory(config);
          final bytes = await _service.save();
          final newInfo = await syncService.uploadDatabase(config, bytes);
          _service.setLastSyncedRemoteInfo(newInfo);
          eTag = newInfo.eTag;
          remoteMTime = newInfo.mTime;
          _ref.read(syncStateProvider.notifier).state = SyncState.success;
        } catch (e) {
          log.e('Initial cloud upload failed', error: e);
          _ref.read(syncStateProvider.notifier).state = SyncState.error;
        }
      } else {
        _currentWebDavProfileId = null;
        _ref.read(openedFromCloudProvider.notifier).state = false;
      }

      await Future.wait([
        recentSvc.addRecentFile(
          filePath,
          isCloud: isCloud,
          remotePath: remotePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: eTag,
          lastSyncedMTime: remoteMTime,
        ),
        recentSvc.setLastOpenedFile(
          filePath,
          isCloud: isCloud,
          remotePath: remotePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: eTag,
          lastSyncedMTime: remoteMTime,
        ),
      ]);
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Saves locally and syncs to WebDAV if enabled.
  /// Returns true on success, false if a conflict was detected (caller should show dialog).
  /// Concurrent callers (auto-save timer, manual save, close, app exit) share
  /// the same in-flight save instead of racing on disk writes and uploads.
  /// A caller that joins an in-flight save gets one more round automatically
  /// when mutations landed while that save was serializing, so awaiting
  /// [save] means the caller's data is actually persisted.
  Future<bool> save() {
    final inFlight = _saveInFlight;
    if (inFlight != null) {
      return inFlight.then((success) async {
        if (!success || !_service.isOpen || !_service.isDirty) return success;
        return _startSave();
      });
    }
    return _startSave();
  }

  Future<bool> _startSave() {
    final session = _session;
    late Future<bool> future;
    future = _doSave(session).whenComplete(() {
      if (identical(_saveInFlight, future)) _saveInFlight = null;
    });
    _saveInFlight = future;
    return future;
  }

  Future<bool> _doSave(int session) async {
    if (session != _session || !_service.isOpen) return false;

    final wasDirty = _service.isDirty;
    final Uint8List bytes;
    try {
      bytes = await _service.save();
    } catch (e) {
      log.e('Local save failed', error: e);
      return false;
    }
    if (session != _session || !_service.isOpen) return false;
    final WebDavConfig? config;
    try {
      config = await _ref
          .read(webDavSettingsServiceProvider)
          .getConfigById(_currentWebDavProfileId);
    } catch (e) {
      log.e('Failed to read WebDAV config', error: e);
      return false;
    }
    // Only sync to cloud if the current database was opened from or created as a cloud database
    if (session != _session || !_service.isOpen) return false;
    if (config != null &&
        config.enabled &&
        _ref.read(openedFromCloudProvider)) {
      _ref.read(syncStateProvider.notifier).state = SyncState.syncing;
      try {
        final syncService = _ref.read(syncServiceProvider);
        // Skip upload if local content hasn't changed since last save
        if (!wasDirty) {
          log.i('Content unchanged, skipping upload');
          _ref.read(syncStateProvider.notifier).state = SyncState.success;
          return true;
        }
        await syncService.ensureRemoteDirectory(config);
        if (session != _session || !_service.isOpen) {
          // Aborted mid-sync (lock/close): never leave the state machine
          // stuck on "syncing".
          _ref.read(syncStateProvider.notifier).state = SyncState.error;
          return false;
        }
        // Conditional PUT: upload only if the remote revision still matches
        // the last known one (If-Match) or is new (If-None-Match). This atomically
        // detects a conflict in a single round trip, avoiding a separate
        // PROPFIND before every save. On a 412 the server rejects the upload
        // and we fall back to the diff dialog below.
        final lastInfo = _service.lastSyncedRemoteInfo;
        final newInfo = await syncService.uploadDatabase(
          config,
          bytes,
          expected: lastInfo,
        );
        if (session != _session) {
          // The database was locked/closed while this upload was in flight.
          // Record the revision (the service is still open at this point) and
          // let the lock/close path persist recent-file metadata, so the two
          // writers cannot race on the pendingUpload marker.
          _service.setLastSyncedRemoteInfo(newInfo);
          return true;
        }
        _service.setLastSyncedRemoteInfo(newInfo);
        // Persist the eTag so next startup can skip redundant download
        if (newInfo.eTag != null && _service.filePath != null) {
          final recentSvc = _ref.read(recentFilesServiceProvider);
          final existing = await recentSvc.getRecentFiles();
          final wasCloud = existing.any(
            (f) => f.path == _service.filePath && f.isCloud,
          );
          await Future.wait([
            recentSvc.addRecentFile(
              _service.filePath!,
              isCloud: wasCloud,
              remotePath: config.remoteFilePath,
              webDavProfileId: _currentWebDavProfileId,
              lastSyncedETag: newInfo.eTag,
              lastSyncedMTime: newInfo.mTime,
              pendingUpload: false,
            ),
            recentSvc.setLastOpenedFile(
              _service.filePath!,
              isCloud: wasCloud,
              remotePath: config.remoteFilePath,
              webDavProfileId: _currentWebDavProfileId,
              lastSyncedETag: newInfo.eTag,
              lastSyncedMTime: newInfo.mTime,
              pendingUpload: false,
            ),
          ]);
        }
        _ref.read(syncStateProvider.notifier).state = SyncState.success;
      } catch (e) {
        log.e('Sync failed', error: e);
        if (e is SyncException && e.type == SyncErrorType.conflict) {
          try {
            _lastSyncAuditReport = await inspectCloudDiff();
          } catch (diffError) {
            // Fetching the diff is best-effort; a failure here must not
            // escape and leave the sync state machine stuck on "syncing".
            log.e('Failed to inspect cloud diff after conflict',
                error: diffError);
          }
          _ref.read(syncStateProvider.notifier).state = SyncState.conflict;
        } else {
          _ref.read(syncStateProvider.notifier).state = SyncState.error;
        }
        _lastSyncError = e;
        return false;
      }
    }
    return true;
  }

  /// Force upload, ignoring conflict detection (used after user chooses to overwrite).
  /// Always persists locally first so disk and cloud stay aligned.
  /// Pass [savedBytes] when the caller has already persisted the database to
  /// avoid a redundant serialization/disk write.
  Future<void> forceUpload({Uint8List? savedBytes}) async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled) return;
    _ref.read(syncStateProvider.notifier).state = SyncState.syncing;
    try {
      final Uint8List bytes;
      if (savedBytes != null) {
        bytes = savedBytes;
      } else {
        // Wait out any in-flight save (including chained follow-up rounds)
        // so its upload cannot race the forced one.
        while (_saveInFlight != null) {
          final inFlight = _saveInFlight!;
          await inFlight.catchError((_) => false);
        }
        if (!_service.isOpen) {
          _ref.read(syncStateProvider.notifier).state = SyncState.error;
          return;
        }
        // Persist to disk (and optional auto-backup) before upload so a crash
        // after overwrite cannot leave local cache behind cloud.
        bytes = await _service.save();
      }
      final syncService = _ref.read(syncServiceProvider);
      await syncService.ensureRemoteDirectory(config);
      final newInfo = await syncService.uploadDatabase(
        config,
        bytes,
        force: true,
      );
      _service.setLastSyncedRemoteInfo(newInfo);
      if (_service.filePath != null) {
        final recentSvc = _ref.read(recentFilesServiceProvider);
        await Future.wait([
          recentSvc.addRecentFile(
            _service.filePath!,
            isCloud: true,
            remotePath: config.remoteFilePath,
            webDavProfileId: _currentWebDavProfileId,
            lastSyncedETag: newInfo.eTag,
            lastSyncedMTime: newInfo.mTime,
            pendingUpload: false,
          ),
          recentSvc.setLastOpenedFile(
            _service.filePath!,
            isCloud: true,
            remotePath: config.remoteFilePath,
            webDavProfileId: _currentWebDavProfileId,
            lastSyncedETag: newInfo.eTag,
            lastSyncedMTime: newInfo.mTime,
            pendingUpload: false,
          ),
        ]);
      }
      _ref.read(syncStateProvider.notifier).state = SyncState.success;
      _lastSyncError = null;
      _lastSyncAuditReport = null;
    } catch (e) {
      _lastSyncError = e;
      _ref.read(syncStateProvider.notifier).state = SyncState.error;
    }
  }

  Future<bool> restoreBackupBytes(Uint8List bytes, {String? password}) async {
    final db = await _service.reloadFromBytes(bytes, password: password);
    final savedBytes = await _service.save();
    state = AsyncValue.data(db);
    unawaited(_ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db));

    if (_ref.read(openedFromCloudProvider)) {
      await forceUpload(savedBytes: savedBytes);
      return _ref.read(syncStateProvider) == SyncState.success;
    }

    return true;
  }

  Future<void> saveAs(String newPath) async {
    await _service.saveAs(newPath);
  }

  Future<void> close() async {
    if (_service.isOpen) {
      try {
        // A save that was already in flight may have serialized before the
        // latest edit (the mutationCount mechanism keeps the dirty flag set in
        // that case). Keep saving until the dirty flag clears so closing never
        // discards mutations that landed mid-serialization.
        for (var attempt = 0; attempt < 3 && _service.isDirty; attempt++) {
          final success = await save();
          if (!success) {
            log.w(
              'Database saved locally before close, but cloud sync reported a conflict.',
            );
            break;
          }
        }
      } catch (e, st) {
        log.e('Failed to save database before close', error: e, stackTrace: st);
      }
    }
    _finishClose();
  }

  /// Locks immediately from the UI's perspective, then persists locally.
  /// Cloud upload continues from encrypted bytes and never delays the lock.
  Future<void> lock() async {
    if (!_service.isOpen) return;
    final lockSession = ++_session;
    final path = _service.filePath;
    final isCloud = _ref.read(openedFromCloudProvider);
    final profileId = _currentWebDavProfileId;

    // Publish the locked state before the first await. Protected pages can no
    // longer read the database while local persistence finishes.
    state = const AsyncValue.data(null);
    _ref.read(isDirtyProvider.notifier).state = false;
    _ref.read(autoLockProvider.notifier).cancelTimer();
    _ref.read(autoSaveProvider.notifier).cancelTimer();
    // An in-flight sync cannot complete once the database is locked.
    _ref.read(syncStateProvider.notifier).state = SyncState.idle;

    // Wait out any in-flight save (including chained follow-up rounds that
    // re-register _saveInFlight) so its upload completes before we snapshot
    // bytes and revision metadata; otherwise the two uploads would race on
    // the remote file and on the recent-file pendingUpload marker.
    while (_saveInFlight != null) {
      final inFlight = _saveInFlight!;
      await inFlight.catchError((_) => false);
      if (lockSession != _session) return;
    }
    // Re-read after joining: the joined save may have uploaded and refreshed
    // the remote revision, so an upload started here must match against it.
    final lastInfo = _service.lastSyncedRemoteInfo;
    final wasDirty = _service.isDirty;

    Uint8List bytes = Uint8List(0);
    Object? localSaveError;
    try {
      if (wasDirty) bytes = await _service.save();
    } catch (e, st) {
      localSaveError = e;
      log.e('Failed to save database before lock', error: e, stackTrace: st);
    }

    if (lockSession != _session) return;
    WebDavConfig? config;
    if (isCloud && path != null && bytes.isNotEmpty) {
      try {
        config = await _ref
            .read(webDavSettingsServiceProvider)
            .getConfigById(profileId);
        if (lockSession != _session) return;
        if (config != null && config.enabled) {
          await _markPendingUpload(
            path,
            config.remoteFilePath,
            profileId,
            lastInfo,
          );
        }
      } catch (e, st) {
        // Cloud bookkeeping (config lookup / pending-upload marker) must not
        // prevent the lock from closing the database and clearing the master
        // password / key file from memory. The local save already succeeded, so
        // data is safe on disk; the upload can resume on next open. We null the
        // config so the background upload below is skipped for this attempt.
        log.e('Failed to mark pending upload during lock', error: e, stackTrace: st);
        config = null;
      }
    }

    _finishClose(clearLastOpened: false);
    if (config != null && config.enabled && path != null && bytes.isNotEmpty) {
      unawaited(
        _uploadEncryptedBytes(
          bytes: bytes,
          config: config,
          path: path,
          profileId: profileId,
          expected: lastInfo,
        ),
      );
    }
    if (localSaveError != null) {
      _ref.read(lastLockErrorProvider.notifier).state = localSaveError;
    }
  }

  Future<bool> resumePendingUpload(RecentFile file) async {
    _ref.read(lastPendingUploadErrorProvider.notifier).state = null;
    if (!file.pendingUpload) return true;
    try {
      if (!file.isCloud || !await File(file.path).exists()) return false;
      final config = await _ref
          .read(webDavSettingsServiceProvider)
          .getConfigById(file.webDavProfileId);
      if (config == null || !config.enabled) return false;
      final bytes = await File(file.path).readAsBytes();
      return await _uploadEncryptedBytes(
        bytes: bytes,
        config: config,
        path: file.path,
        profileId: file.webDavProfileId,
        expected: RemoteFileInfo(
          eTag: file.lastSyncedETag,
          mTime: file.lastSyncedMTime,
        ),
      );
    } catch (e, st) {
      _ref.read(lastPendingUploadErrorProvider.notifier).state = e;
      log.e('Unable to resume pending cloud upload', error: e, stackTrace: st);
      return false;
    }
  }

  Future<bool> _uploadEncryptedBytes({
    required Uint8List bytes,
    required WebDavConfig config,
    required String path,
    required String? profileId,
    required RemoteFileInfo? expected,
  }) async {
    try {
      final sync = _ref.read(syncServiceProvider);
      await sync.ensureRemoteDirectory(config);
      final info = await sync.uploadDatabase(config, bytes, expected: expected);
      await _persistCloudRevision(
        path: path,
        remotePath: config.remoteFilePath,
        profileId: profileId,
        info: info,
        pendingUpload: false,
      );
      _ref.read(lastPendingUploadErrorProvider.notifier).state = null;
      _ref.invalidate(recentFilesProvider);
      return true;
    } catch (e, st) {
      _ref.read(lastPendingUploadErrorProvider.notifier).state = e;
      log.e('Pending cloud upload failed', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> _markPendingUpload(
    String path,
    String remotePath,
    String? profileId,
    RemoteFileInfo? info,
  ) => _persistCloudRevision(
    path: path,
    remotePath: remotePath,
    profileId: profileId,
    info: info,
    pendingUpload: true,
  );

  Future<void> _persistCloudRevision({
    required String path,
    required String remotePath,
    required String? profileId,
    required RemoteFileInfo? info,
    required bool pendingUpload,
  }) async {
    final recent = _ref.read(recentFilesServiceProvider);
    await Future.wait([
      recent.addRecentFile(
        path,
        isCloud: true,
        remotePath: remotePath,
        webDavProfileId: profileId,
        lastSyncedETag: info?.eTag,
        lastSyncedMTime: info?.mTime,
        pendingUpload: pendingUpload,
      ),
      recent.setLastOpenedFile(
        path,
        isCloud: true,
        remotePath: remotePath,
        webDavProfileId: profileId,
        lastSyncedETag: info?.eTag,
        lastSyncedMTime: info?.mTime,
        pendingUpload: pendingUpload,
      ),
    ]);
  }

  void _finishClose({bool clearLastOpened = true}) {
    ++_session;
    _saveInFlight = null;
    _service.close();
    state = const AsyncValue.data(null);
    _currentWebDavProfileId = null;
    // Dropping the reference stops copy shortcuts from reading fields of a
    // closed (locked) database.
    _ref.read(activeEntryProvider.notifier).state = null;
    _ref.read(openedFromCloudProvider.notifier).state = false;
    _ref.read(syncStateProvider.notifier).state = SyncState.idle;
    if (clearLastOpened) {
      unawaited(_ref.read(recentFilesServiceProvider).clearLastOpenedFile());
    }
    _ref.read(autoLockProvider.notifier).cancelTimer();
    _ref.read(autoSaveProvider.notifier).cancelTimer();
    _ref.read(syncServiceProvider).clearCache();
    _ref.invalidate(recentFilesProvider);
  }

  Future<void> reloadFromCloud() async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled) {
      throw Exception('please_configure_webdav');
    }
    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.downloadWithInfo(config);
    if (result == null) throw Exception('cloud_database_not_exist');
    final db = await _service.reloadFromBytes(result.bytes);
    // Persist downloaded bytes so local cache matches what is now open in memory.
    await _service.save();
    _service.setLastSyncedRemoteInfo(result.info);
    state = AsyncValue.data(db);
    unawaited(_ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db));
    if (_service.filePath != null) {
      final recentSvc = _ref.read(recentFilesServiceProvider);
      final existing = await recentSvc.getRecentFiles();
      final wasCloud = existing.any(
        (f) => f.path == _service.filePath && f.isCloud,
      );
      await Future.wait([
        recentSvc.addRecentFile(
          _service.filePath!,
          isCloud: wasCloud,
          remotePath: config.remoteFilePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: result.info.eTag,
          lastSyncedMTime: result.info.mTime,
          pendingUpload: false,
        ),
        recentSvc.setLastOpenedFile(
          _service.filePath!,
          isCloud: wasCloud,
          remotePath: config.remoteFilePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: result.info.eTag,
          lastSyncedMTime: result.info.mTime,
          pendingUpload: false,
        ),
      ]);
    }
  }

  /// Checks if the remote file has changed since last sync.
  /// Returns true if remote has newer changes (conflict).
  Future<bool> checkRemoteChanges() async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled) return false;
    final syncService = _ref.read(syncServiceProvider);
    final remoteInfo = await syncService.getRemoteFileInfo(config);
    final lastInfo = _service.lastSyncedRemoteInfo;
    if (remoteInfo == null || lastInfo == null) return false;
    return _hasRemoteChanged(remoteInfo, lastInfo);
  }

  Future<SyncAuditReport?> inspectCloudDiff() async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled || _service.db == null) return null;

    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.downloadWithInfo(config);
    if (result == null) return null;

    final report = await _service.buildSyncAuditReportFromBytes(result.bytes);
    _lastSyncAuditReport = report;
    return report;
  }

  bool _hasRemoteChanged(RemoteFileInfo? remoteInfo, RemoteFileInfo? lastInfo) {
    if (remoteInfo == null || lastInfo == null) return false;
    // normalizeETag also makes records stored before weak-ETag normalization
    // compare equal to their normalized remote counterparts.
    if (remoteInfo.eTag != null && lastInfo.eTag != null) {
      return normalizeETag(remoteInfo.eTag) != normalizeETag(lastInfo.eTag);
    }
    if (remoteInfo.mTime != null && lastInfo.mTime != null) {
      return remoteInfo.mTime != lastInfo.mTime;
    }
    return false;
  }

  Future<void> changePassword(
    String oldPassword,
    String newPassword, {
    bool updateKeyFile = false,
    Uint8List? newKeyData,
  }) async {
    _service.changePassword(
      oldPassword,
      newPassword,
      updateKeyFile: updateKeyFile,
      newKeyData: newKeyData,
    );
    // Save + sync to cloud if enabled.
    await save();
  }

  void markDirty() => _service.markDirty();
  bool get isDirty => _service.isDirty;
  bool get hasKeyFile => _service.hasKeyFile;
}

final recentFilesProvider = FutureProvider<List<RecentFile>>((ref) async {
  return ref.read(recentFilesServiceProvider).getRecentFiles();
});

/// Whether the current database was opened from WebDAV (cloud).
final openedFromCloudProvider = StateProvider<bool>((ref) => false);

final cloudOfflineModeProvider = StateProvider<bool>((ref) => false);

final cloudOfflineReasonProvider = StateProvider<String?>((ref) => null);

/// Whether the database has unsaved changes.
final isDirtyProvider = StateProvider<bool>((ref) => false);

/// Last local persistence error raised while security-locking.
final lastLockErrorProvider = StateProvider<Object?>((ref) => null);

/// Last error raised while resuming an encrypted pending cloud upload.
final lastPendingUploadErrorProvider = StateProvider<Object?>((ref) => null);
