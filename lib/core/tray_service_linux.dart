import 'package:flutter/foundation.dart';
import 'package:dart_xdg_status_notifier_item/dart_xdg_status_notifier_item.dart';
import 'theme/theme_seed.dart';
import 'theme/theme_seed_icons.dart';
import 'utils/logger.dart';
import 'tray_service.dart';

TrayServiceBase createTrayServiceLinux() => TrayServiceLinux();

class TrayServiceLinux implements TrayServiceBase {
  StatusNotifierItemClient? _client;
  bool _initialized = false;
  ThemeSeed _seed = ThemeSeed.indigo;

  @override
  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  }) async {
    if (_initialized) return;

    final iconPath = ThemeSeedIcons.resolveLinuxAbsolutePath(_seed);
    log.d('TrayServiceLinux: Using icon path: $iconPath');

    // Create menu items
    final menu = DBusMenuItem(children: [
      DBusMenuItem(
        label: showLabel,
        onClicked: () async {
          log.d('TrayServiceLinux: Show window clicked');
          onShowWindow();
        },
      ),
      DBusMenuItem.separator(),
      DBusMenuItem(
        label: exitLabel,
        onClicked: () async {
          log.d('TrayServiceLinux: Exit clicked');
          onExitApp();
        },
      ),
    ]);

    // Create StatusNotifierItem client
    _client = StatusNotifierItemClient(
      id: 'keestone',
      iconName: iconPath,
      menu: menu,
    );

    try {
      log.d('TrayServiceLinux: Connecting to D-Bus...');
      await _client!.connect();
      _initialized = true;
      // Seed may have changed while the tray was starting up.
      _client!.iconName = ThemeSeedIcons.resolveLinuxAbsolutePath(_seed);
      log.d('TrayServiceLinux: Connected successfully');
    } catch (e, stackTrace) {
      log.e('TrayServiceLinux: Failed to connect', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> setSeedIcon(ThemeSeed seed) async {
    _seed = seed;
    final client = _client;
    if (!_initialized || client == null) return;
    final iconPath = ThemeSeedIcons.resolveLinuxAbsolutePath(seed);
    try {
      client.iconName = iconPath;
    } catch (e) {
      log.w('TrayServiceLinux: setSeedIcon failed for $iconPath', error: e);
    }
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _client?.close();
      _initialized = false;
    }
  }
}
