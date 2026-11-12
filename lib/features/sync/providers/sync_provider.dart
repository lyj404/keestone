import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../settings/data/webdav_config.dart';
import '../data/git_config.dart';
import '../data/s3_config.dart';
import '../data/s3_settings_service.dart';
import '../data/s3_sync_service.dart';
import '../data/sync_service.dart';
import '../data/git_settings_service.dart';
import '../data/git_sync_service.dart';

enum SyncState { idle, syncing, success, error, conflict }

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

final gitSettingsServiceProvider = Provider<GitSettingsService>((ref) {
  return GitSettingsService();
});

final gitSyncServiceProvider = Provider<GitSyncService>((ref) {
  return GitSyncService();
});

final s3SettingsServiceProvider = Provider<S3SettingsService>((ref) {
  return S3SettingsService();
});

final s3SyncServiceProvider = Provider<S3SyncService>((ref) {
  return S3SyncService();
});

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);

/// The sync backend resolved for a profile id (or null = auto). Shared by
/// every sync entry point so they cannot disagree about which backend to
/// use or report misleading "configure WebDAV" errors for Git users.
class ResolvedSyncBackend {
  final GitSyncConfig? git;
  final S3SyncConfig? s3;
  final WebDavConfig? webdav;

  const ResolvedSyncBackend({this.git, this.s3, this.webdav});

  bool get hasGit => (git?.enabled) ?? false;
  bool get hasS3 => (s3?.enabled) ?? false;
  bool get hasWebdav => (webdav?.enabled) ?? false;
  bool get hasEnabled => hasGit || hasS3 || hasWebdav;
}

/// Resolution rules (must stay the single source of truth):
/// - `git_`-prefixed id: only that Git profile qualifies.
/// - `s3_`-prefixed id: only that S3 profile qualifies.
/// - otherwise: the highest-priority enabled config wins in the order
///   Git > S3 > WebDAV (the profile id spaces are disjoint, so Git and S3
///   are looked up without the id), then the WebDAV profile matching
///   [profileId] (or the active one when null).
Future<ResolvedSyncBackend> resolveSyncBackend(
  Future<GitSyncConfig?> Function(String? id) gitConfigById,
  Future<S3SyncConfig?> Function(String? id) s3ConfigById,
  Future<WebDavConfig?> Function(String? id) webDavConfigById,
  String? profileId,
) async {
  if (profileId != null && profileId.startsWith('git_')) {
    return ResolvedSyncBackend(git: await gitConfigById(profileId));
  }
  if (profileId != null && profileId.startsWith('s3_')) {
    return ResolvedSyncBackend(s3: await s3ConfigById(profileId));
  }
  final git = await gitConfigById(null);
  if (git != null && git.enabled) {
    return ResolvedSyncBackend(git: git);
  }
  final s3 = await s3ConfigById(null);
  if (s3 != null && s3.enabled) {
    return ResolvedSyncBackend(s3: s3);
  }
  final webdav = await webDavConfigById(profileId);
  return ResolvedSyncBackend(git: git, s3: s3, webdav: webdav);
}
