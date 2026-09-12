import 'dart:io';

import 'theme_seed.dart';

/// Resolves bundled per-seed tray/window icon assets.
///
/// Launcher / install-level icons stay on the default `app_icon.*` (static).
/// Only in-process surfaces (system tray, window titlebar) switch with seed.
class ThemeSeedIcons {
  /// Flutter asset path relative to `assets/` root used by `rootBundle`
  /// and by `system_tray` / `window_manager` path joiners.
  static String assetPath(ThemeSeed seed) {
    if (Platform.isWindows) {
      return 'assets/icons/seeds/${seed.name}.ico';
    }
    return 'assets/icons/seeds/${seed.name}.png';
  }

  /// Absolute path for Linux StatusNotifierItem (expects a filesystem path).
  static String resolveLinuxAbsolutePath(ThemeSeed seed) {
    final rel = assetPath(seed);
    final exePath = Platform.resolvedExecutable;
    final exeDir = exePath.substring(
      0,
      exePath.lastIndexOf(Platform.pathSeparator),
    );
    final releasePath = '$exeDir/data/flutter_assets/$rel';
    final debugPath = '$exeDir/../../../data/flutter_assets/$rel';
    if (File(releasePath).existsSync()) {
      return releasePath;
    }
    if (File(debugPath).existsSync()) {
      return File(debugPath).resolveSymbolicLinksSync();
    }
    return releasePath;
  }
}
