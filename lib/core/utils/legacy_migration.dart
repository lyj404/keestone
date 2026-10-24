import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'logger.dart';

/// One-time best-effort migration of data written by the pre-rename
/// "KeeVault" build. Desktop installs keep their on-disk layout, so the old
/// directories are renamed to the new identity when the new ones don't exist
/// yet. Mobile sandbox paths change with the application id, so there is
/// nothing to migrate there.
class LegacyMigration {
  const LegacyMigration._();

  static Future<void> run() async {
    try {
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        final xdg =
            Platform.environment['XDG_DATA_HOME'] ??
            (home != null ? '$home/.local/share' : null);
        if (xdg != null) {
          // Error logs (FileLogOutput).
          await _migrateDir(
            Directory('$xdg/keevault'),
            Directory('$xdg/keestone'),
          );
          // App support data (backups, path_provider support dir).
          await _migrateDir(
            Directory('$xdg/com.keevault.keevault'),
            Directory('$xdg/com.keestone.keestone'),
          );
        }
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          await _migrateDir(
            Directory('$appData\\com.keevault'),
            Directory('$appData\\com.keestone'),
          );
        }
      }
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        // WebDAV cloud cache under the user's documents directory.
        final docs = await getApplicationDocumentsDirectory();
        await _migrateDir(
          Directory('${docs.path}/keevault_cloud_cache'),
          Directory('${docs.path}/keestone_cloud_cache'),
        );
      }
    } catch (e) {
      log.w('Legacy data migration failed', error: e);
    }
  }

  static Future<void> _migrateDir(Directory from, Directory to) async {
    if (!await from.exists() || await to.exists()) return;
    try {
      await from.rename(to.path);
    } catch (e) {
      // Cross-device renames fail; fall back to a copy so the user still
      // gets their data under the new name.
      try {
        await _copyDirectory(from, to);
        await from.delete(recursive: true);
      } catch (_) {
        log.w('Legacy data migration failed for ${from.path}', error: e);
      }
    }
  }

  static Future<void> _copyDirectory(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final entry in from.list()) {
      final newPath = '${to.path}/${entry.uri.pathSegments.last}';
      if (entry is File) {
        await entry.copy(newPath);
      } else if (entry is Directory) {
        await _copyDirectory(entry, Directory(newPath));
      }
    }
  }
}
