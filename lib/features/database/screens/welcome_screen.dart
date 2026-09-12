import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/data/sync_service.dart'
    show RemoteFileInfo, SyncException, SyncErrorType, normalizeETag;
import '../../sync/providers/sync_provider.dart';
import '../providers/database_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  // Static to persist across widget rebuilds; resets only on app restart
  static bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoOpen());
  }

  Future<void> _tryAutoOpen() async {
    if (_autoOpened) return;
    // Only auto-open when there's exactly one recent file
    final files = await ref.read(recentFilesServiceProvider).getRecentFiles();
    if (files.length != 1) return;
    if (!mounted) return;

    var file = files.first;
    if (file.pendingUpload) {
      final resumed = await ref
          .read(databaseProvider.notifier)
          .resumePendingUpload(file);
      if (!mounted) return;
      if (!resumed) {
        final error = ref.read(lastPendingUploadErrorProvider);
        final l10n = AppLocalizations.of(context)!;
        final message =
            error is SyncException && error.type == SyncErrorType.conflict
            ? l10n.pendingUploadConflict
            : l10n.pendingUploadFailed;
        await _showSimpleErrorDialog(context, message);
        if (!mounted) return;
      } else {
        final refreshed = await ref
            .read(recentFilesServiceProvider)
            .getRecentFiles();
        final matching = refreshed.where((item) => item.path == file.path);
        if (matching.isNotEmpty) file = matching.first;
      }
    }
    final localFile = File(file.path);
    final exists = await localFile.exists();
    if (!mounted) return;

    if (!file.isCloud) {
      if (exists && mounted) {
        _autoOpened = true;
        unawaited(context.push('/unlock?path=${Uri.encodeComponent(file.path)}'));
      }
      return;
    }

    final config = await ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(file.webDavProfileId);
    if (config == null || !config.enabled) {
      if (exists) {
        // Local file exists but WebDAV not configured — open as local file.
        if (mounted) {
          unawaited(context.push('/unlock?path=${Uri.encodeComponent(file.path)}'));
        }
      } else {
        // Local cache missing and no WebDAV config — remove stale record.
        await ref.read(recentFilesServiceProvider).removeRecentFile(file.path);
        ref.invalidate(recentFilesProvider);
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorDialog(context, l10n.cloudDatabaseNotExist);
        }
      }
      return;
    }
    if (!exists) {
      // Local cache missing but WebDAV is configured — fall through to download.
    }
    final syncService = ref.read(syncServiceProvider);
    RemoteFileInfo? remoteInfo;
    try {
      remoteInfo = await syncService.getRemoteFileInfo(config);
    } catch (e) {
      // Unreachable server is not the same as "no cloud database"; fall back
      // to the local cache instead of pretending the remote is gone.
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final message = _translateDownloadError(e, l10n);
      if (exists) {
        _setCloudOfflineMode(message);
        unawaited(
          context.push(
            _buildCloudUnlockQuery(file.path, null, file.webDavProfileId),
          ),
        );
      } else {
        _showErrorDialog(context, message);
      }
      return;
    }
    if (!mounted) return;
    if (remoteInfo != null) {
      if (_isCachedCopyCurrent(file, remoteInfo) && exists) {
        _setCloudOnlineMode();
        ref.read(openedFromCloudProvider.notifier).state = true;
        final query = _buildCloudUnlockQuery(
          file.path,
          remoteInfo,
          file.webDavProfileId,
        );
        unawaited(context.push(query));
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _SyncLoadingDialog(message: l10n.syncingCloudDatabase),
        ),
      );
      var loadingVisible = true;
      void dismissLoading() {
        if (!loadingVisible || !mounted) return;
        loadingVisible = false;
        Navigator.of(context).pop();
      }

      try {
        if (exists) {
          final action = await _resolveCloudOpenAction(
            context,
            l10n,
            hasLocalCache: true,
            remoteChanged: !_isCachedCopyCurrent(file, remoteInfo),
          );
          if (!mounted) return;
          if (action == _CloudOpenAction.useCache) {
            dismissLoading();
            _setCloudOfflineMode(l10n.openLocalDatabase);
            ref.read(openedFromCloudProvider.notifier).state = true;
            unawaited(
              context.push(
                _buildCloudUnlockQuery(file.path, null, file.webDavProfileId),
              ),
            );
            return;
          }
          if (action != _CloudOpenAction.downloadLatest) {
            dismissLoading();
            return;
          }
        }
        final downloaded = await syncService.downloadToLocal(config);
        final localPath = downloaded.path;
        final downloadedInfo = downloaded.info;
        final recentService = ref.read(recentFilesServiceProvider);
        await recentService.addRecentFile(
          localPath,
          isCloud: true,
          remotePath: config.remoteFilePath,
          webDavProfileId: config.id,
          lastSyncedETag: downloadedInfo.eTag ?? remoteInfo.eTag,
          lastSyncedMTime: downloadedInfo.mTime ?? remoteInfo.mTime,
        );
        await recentService.setLastOpenedFile(
          localPath,
          isCloud: true,
          remotePath: config.remoteFilePath,
          webDavProfileId: config.id,
          lastSyncedETag: downloadedInfo.eTag ?? remoteInfo.eTag,
          lastSyncedMTime: downloadedInfo.mTime ?? remoteInfo.mTime,
        );
        _setCloudOnlineMode();
        dismissLoading();
        if (mounted) {
          ref.read(openedFromCloudProvider.notifier).state = true;
          unawaited(
            context.push(
              _buildCloudUnlockQuery(
                localPath,
                downloadedInfo.eTag != null || downloadedInfo.mTime != null
                    ? downloadedInfo
                    : remoteInfo,
                config.id,
              ),
            ),
          );
        }
      } catch (e) {
        _autoOpened = false;
        dismissLoading();
        if (mounted && exists) {
          _setCloudOfflineMode(_translateDownloadError(e, l10n));
          ref.read(openedFromCloudProvider.notifier).state = true;
          unawaited(
            context.push(
              _buildCloudUnlockQuery(file.path, null, file.webDavProfileId),
            ),
          );
        } else if (mounted) {
          _showErrorDialog(context, _translateDownloadError(e, l10n));
        }
      }
    } else {
      if (exists) {
        _setCloudOfflineMode(
          AppLocalizations.of(context)!.cloudDatabaseNotExist,
        );
        ref.read(openedFromCloudProvider.notifier).state = true;
        unawaited(
          context.push(
            _buildCloudUnlockQuery(file.path, null, file.webDavProfileId),
          ),
        );
      } else {
        _showErrorDialog(
          context,
          AppLocalizations.of(context)!.cloudDatabaseNotExist,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentFiles = ref.watch(recentFilesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.appSubtitle,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 44),

                    // Primary action – clay button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: () => _openFile(context),
                        icon: const Icon(Icons.folder_open_rounded, size: 20),
                        label: Text(l10n.openLocalDatabase),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Secondary action
                    OutlinedButton.icon(
                      onPressed: () => context.push('/create'),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(l10n.createNewDatabase),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Download from WebDAV
                    OutlinedButton.icon(
                      onPressed: () => _downloadFromWebDav(context),
                      icon: const Icon(Icons.cloud_download_rounded, size: 20),
                      label: Text(l10n.openCloudDatabase),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),

                    // Recent files
                    recentFiles.when(
                      data: (files) {
                        if (files.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l10n.recentOpened,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${files.length}',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...files.map(
                                (file) => _RecentFileTile(
                                  recentFile: file,
                                  onTap: () {
                                    if (file.isCloud) {
                                      ref
                                              .read(
                                                openedFromCloudProvider
                                                    .notifier,
                                              )
                                              .state =
                                          true;
                                      _downloadFromWebDav(
                                        context,
                                        recentFile: file,
                                      );
                                    } else {
                                      context.push(
                                        '/unlock?path=${Uri.encodeComponent(file.path)}',
                                      );
                                    }
                                  },
                                  onRemove: () async {
                                    await ref
                                        .read(recentFilesServiceProvider)
                                        .removeRecentFile(file.path);
                                    ref.invalidate(recentFilesProvider);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Settings icon - top right
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: ClayDecoration.iconContainer(
                    brightness: Theme.of(context).brightness,
                    radius: 12,
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    try {
      // Android/iOS FilePicker has no MIME mapping for `.kdbx` custom types.
      final isMobile = Platform.isAndroid || Platform.isIOS;
      final file = await FilePicker.pickFile(
        type: isMobile ? FileType.any : FileType.custom,
        allowedExtensions: isMobile ? null : ['kdbx'],
      );
      final path = file?.path;
      if (path != null && context.mounted) {
        unawaited(context.push('/unlock?path=${Uri.encodeComponent(path)}'));
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, e.message ?? e.code);
      }
    }
  }

  Future<void> _downloadFromWebDav(
    BuildContext context, {
    RecentFile? recentFile,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final config = await ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(recentFile?.webDavProfileId);
    if (config == null) {
      if (context.mounted) {
        _showErrorDialog(context, l10n.pleaseConfigureWebDAV);
      }
      return;
    }
    if (!config.enabled) {
      if (context.mounted) {
        _showCloudDisabledDialog(context, l10n);
      }
      return;
    }
    if (!context.mounted) return;
    final syncService = ref.read(syncServiceProvider);
    RemoteFileInfo? remoteInfo;
    try {
      remoteInfo = await syncService.getRemoteFileInfo(config);
    } catch (e) {
      // Auth/network failure must not be presented as "cloud has no database"
      // — that would guide the user into creating/overwriting a real one.
      if (context.mounted) {
        _showErrorDialog(context, _translateDownloadError(e, l10n));
      }
      return;
    }
    if (remoteInfo == null) {
      if (context.mounted) {
        _showCloudNoDatabaseDialog(context, l10n);
      }
      return;
    }

    // eTag check: skip download if local cache is already up-to-date
    // Always look up latest from service to avoid stale etag from cached provider
    final recentFiles = await ref
        .read(recentFilesServiceProvider)
        .getRecentFiles();
    var cachedFile = recentFiles
        .where((f) => f.isCloud && f.remotePath == config.remoteFilePath)
        .firstOrNull;
    if (cachedFile != null && cachedFile.isCloud) {
      final localFile = File(cachedFile.path);
      final exists = await localFile.exists();
      if (exists && _isCachedCopyCurrent(cachedFile, remoteInfo)) {
        // Local cache is current, open directly
        _setCloudOnlineMode();
        ref.read(openedFromCloudProvider.notifier).state = true;
        if (context.mounted) {
          unawaited(
            context.push(
              _buildCloudUnlockQuery(
                cachedFile.path,
                remoteInfo,
                cachedFile.webDavProfileId,
              ),
            ),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _SyncLoadingDialog(message: l10n.downloadingFromCloud),
      ),
    );
    var loadingVisible = true;
    void dismissLoading() {
      if (!loadingVisible || !context.mounted) return;
      loadingVisible = false;
      Navigator.of(context).pop();
    }

    try {
      final cachedExists = cachedFile != null
          ? await File(cachedFile.path).exists()
          : false;
      if (cachedExists) {
        if (!mounted) return;
        final action = await _resolveCloudOpenAction(
          this.context,
          l10n,
          hasLocalCache: true,
          remoteChanged: !_isCachedCopyCurrent(cachedFile, remoteInfo),
        );
        if (!mounted) return;
        if (action == _CloudOpenAction.useCache) {
          dismissLoading();
          _setCloudOfflineMode(l10n.openLocalDatabase);
          ref.read(openedFromCloudProvider.notifier).state = true;
          unawaited(
            this.context.push(
              _buildCloudUnlockQuery(
                cachedFile.path,
                null,
                cachedFile.webDavProfileId,
              ),
            ),
          );
          return;
        }
        if (action != _CloudOpenAction.downloadLatest) {
          dismissLoading();
          return;
        }
      }
      final downloaded = await syncService.downloadToLocal(config);
      final localPath = downloaded.path;
      final downloadedInfo = downloaded.info;
      final recentService = ref.read(recentFilesServiceProvider);
      await recentService.addRecentFile(
        localPath,
        isCloud: true,
        remotePath: config.remoteFilePath,
        webDavProfileId: config.id,
        lastSyncedETag: downloadedInfo.eTag ?? remoteInfo.eTag,
        lastSyncedMTime: downloadedInfo.mTime ?? remoteInfo.mTime,
      );
      await recentService.setLastOpenedFile(
        localPath,
        isCloud: true,
        remotePath: config.remoteFilePath,
        webDavProfileId: config.id,
        lastSyncedETag: downloadedInfo.eTag ?? remoteInfo.eTag,
        lastSyncedMTime: downloadedInfo.mTime ?? remoteInfo.mTime,
      );
      _setCloudOnlineMode();
      ref.invalidate(recentFilesProvider);
      dismissLoading();
      if (context.mounted) {
        ref.read(openedFromCloudProvider.notifier).state = true;
        unawaited(
          context.push(
            _buildCloudUnlockQuery(
              localPath,
              downloadedInfo.eTag != null || downloadedInfo.mTime != null
                  ? downloadedInfo
                  : remoteInfo,
              config.id,
            ),
          ),
        );
      }
    } catch (e) {
      dismissLoading();
      if (!context.mounted) return;
      if (cachedFile != null) {
        final cachedLocalFile = File(cachedFile.path);
        final cachedExists = await cachedLocalFile.exists();
        if (!context.mounted) return;
        if (cachedExists) {
          _setCloudOfflineMode(_translateDownloadError(e, l10n));
          ref.read(openedFromCloudProvider.notifier).state = true;
          unawaited(
            context.push(
              _buildCloudUnlockQuery(
                cachedFile.path,
                null,
                cachedFile.webDavProfileId,
              ),
            ),
          );
          return;
        }
      }
      if (!context.mounted) return;
      _showErrorDialog(context, _translateDownloadError(e, l10n));
    }
  }

  bool _isCachedCopyCurrent(RecentFile file, RemoteFileInfo remoteInfo) {
    if (file.pendingUpload) return false;
    // normalizeETag also makes records stored before weak-ETag normalization
    // compare equal to their normalized remote counterparts.
    if (file.lastSyncedETag != null && remoteInfo.eTag != null) {
      return normalizeETag(file.lastSyncedETag) ==
          normalizeETag(remoteInfo.eTag);
    }
    if (file.lastSyncedMTime != null && remoteInfo.mTime != null) {
      return file.lastSyncedMTime == remoteInfo.mTime;
    }
    return false;
  }

  String _buildCloudUnlockQuery(
    String path,
    RemoteFileInfo? remoteInfo,
    String? profileId,
  ) {
    final query = StringBuffer(
      '/unlock?path=${Uri.encodeComponent(path)}&cloud=true',
    );
    if (profileId != null) {
      query.write('&profile=${Uri.encodeComponent(profileId)}');
    }
    final remoteETag = remoteInfo?.eTag;
    if (remoteETag != null) {
      query.write('&etag=${Uri.encodeComponent(remoteETag)}');
    }
    return query.toString();
  }

  Future<void> _showSimpleErrorDialog(BuildContext context, String message) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(ctx)!.confirm),
            ),
          ],
        ),
      );

  void _showErrorDialog(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(l10n.cancel),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/settings');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.goToSettings),
          ),
        ],
      ),
    );
  }

  void _showCloudDisabledDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.cloudSyncDisabled),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(l10n.cancel),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/settings');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.goToSettings),
          ),
        ],
      ),
    );
  }

  void _showCloudNoDatabaseDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.cloudNoDatabaseCreateFirst),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(l10n.cancel),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/create');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(l10n.createNewDatabase),
          ),
        ],
      ),
    );
  }

  String _translateDownloadError(Object e, AppLocalizations l10n) {
    if (e is SyncException) {
      switch (e.type) {
        case SyncErrorType.network:
          return l10n.syncErrorNetwork;
        case SyncErrorType.auth:
          return l10n.syncErrorAuth;
        case SyncErrorType.notFound:
          return l10n.syncErrorNotFound;
        case SyncErrorType.timeout:
          return l10n.syncErrorTimeout;
        case SyncErrorType.conflict:
          return l10n.syncConflict;
        case SyncErrorType.serverError:
          return l10n.syncErrorServer;
        case SyncErrorType.unknown:
          break;
      }
    }
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg == 'remote_database_not_exist') return l10n.remoteDatabaseNotExist;
    return l10n.downloadFailed(msg);
  }

  void _setCloudOfflineMode(String reason) {
    ref.read(cloudOfflineModeProvider.notifier).state = true;
    ref.read(cloudOfflineReasonProvider.notifier).state = reason;
  }

  void _setCloudOnlineMode() {
    ref.read(cloudOfflineModeProvider.notifier).state = false;
    ref.read(cloudOfflineReasonProvider.notifier).state = null;
  }

  Future<_CloudOpenAction?> _resolveCloudOpenAction(
    BuildContext context,
    AppLocalizations l10n, {
    required bool hasLocalCache,
    required bool remoteChanged,
  }) {
    return showDialog<_CloudOpenAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cloudDatabase),
        content: Text(
          remoteChanged && hasLocalCache
              ? l10n.cloudModifiedSyncLatest
              : l10n.downloadingFromCloud,
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_CloudOpenAction.downloadLatest),
                child: Text(l10n.downloadFromCloud),
              ),
              const SizedBox(height: 8),
              if (hasLocalCache)
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_CloudOpenAction.useCache),
                  child: Text(l10n.openLocalDatabase),
                ),
              if (hasLocalCache) const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_CloudOpenAction.cancel),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _CloudOpenAction { downloadLatest, useCache, cancel }

class _SyncLoadingDialog extends StatelessWidget {
  final String message;
  const _SyncLoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _RecentFileTile extends StatelessWidget {
  final RecentFile recentFile;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentFileTile({
    required this.recentFile,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = recentFile.path.split(Platform.pathSeparator).last;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: ClayDecoration.card(brightness: brightness),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: ClayDecoration.iconContainer(
                      brightness: brightness,
                      radius: 12,
                    ),
                    child: Icon(
                      recentFile.isCloud
                          ? Icons.cloud_rounded
                          : Icons.description_rounded,
                      size: 18,
                      color: recentFile.isCloud
                          ? colorScheme.secondary
                          : colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recentFile.isCloud
                              ? '${l10n.cloudPrefix} · ${recentFile.remotePath ?? recentFile.path}'
                              : recentFile.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onRemove,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
