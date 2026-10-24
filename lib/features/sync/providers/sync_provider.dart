import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../settings/data/webdav_config.dart';
import '../data/git_config.dart';
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

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);

/// The sync backend resolved for a profile id (or null = auto). Shared by
/// every sync entry point so they cannot disagree about which backend to
/// use or report misleading "configure WebDAV" errors for Git users.
class ResolvedSyncBackend {
  final GitSyncConfig? git;
  final WebDavConfig? webdav;

  const ResolvedSyncBackend({this.git, this.webdav});

  bool get hasGit => (git?.enabled) ?? false;
  bool get hasWebdav => (webdav?.enabled) ?? false;
  bool get hasEnabled => hasGit || hasWebdav;
}

/// Resolution rules (must stay the single source of truth):
/// - `git_`-prefixed id: only that Git profile qualifies.
/// - otherwise: an enabled Git config wins (a Git profile id can never
///   collide with a WebDAV id, so Git is looked up without the id), then the
///   WebDAV profile matching [profileId] (or the active one when null).
Future<ResolvedSyncBackend> resolveSyncBackend(
  Future<GitSyncConfig?> Function(String? id) gitConfigById,
  Future<WebDavConfig?> Function(String? id) webDavConfigById,
  String? profileId,
) async {
  if (profileId != null && profileId.startsWith('git_')) {
    return ResolvedSyncBackend(git: await gitConfigById(profileId));
  }
  final git = await gitConfigById(null);
  if (git != null && git.enabled) {
    return ResolvedSyncBackend(git: git);
  }
  final webdav = await webDavConfigById(profileId);
  return ResolvedSyncBackend(git: git, webdav: webdav);
}
