import 'dart:io';

import 'theme_seed.dart';

/// Resolves bundled per-seed tray/window icon assets.
///
/// Launcher / install-level icons stay on the default `app_icon.*` (static).
/// Only in-process surfaces (system tray, window titlebar) switch with seed.
class ThemeSeedIcons {
  /// Flutter asset path relative to `assets/` root used by `rootBundle`
  /// and by the tray and window icon loaders.
  static String assetPath(ThemeSeed seed) {
    if (Platform.isWindows) {
      return 'assets/icons/seeds/${seed.name}.ico';
    }
    return 'assets/icons/seeds/${seed.name}.png';
  }
}
