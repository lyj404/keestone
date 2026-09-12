import 'package:material_ui/material_ui.dart';
import 'package:system_tray/system_tray.dart';
import 'theme/theme_seed.dart';
import 'theme/theme_seed_icons.dart';
import 'utils/logger.dart';
import 'tray_service.dart';

TrayServiceBase createTrayServiceDesktop() => TrayServiceDesktop();

class TrayServiceDesktop implements TrayServiceBase {
  final SystemTray _tray = SystemTray();
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

    final iconPath = ThemeSeedIcons.assetPath(_seed);

    try {
      await _tray.initSystemTray(
        title: 'KeeStone',
        iconPath: iconPath,
      );
    } catch (e) {
      log.e('TrayServiceDesktop: initSystemTray failed for $iconPath', error: e);
      rethrow;
    }

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: showLabel, onClicked: (_) => onShowWindow()),
      MenuItemLabel(label: exitLabel, onClicked: (_) => onExitApp()),
    ]);

    await _tray.setContextMenu(menu);
    _tray.registerSystemTrayEventHandler((String eventType) {
      if (eventType == kSystemTrayEventClick) {
        onShowWindow();
      } else if (eventType == kSystemTrayEventDoubleClick) {
        onShowWindow();
      } else if (eventType == kSystemTrayEventRightClick) {
        _tray.popUpContextMenu();
      }
    });

    _initialized = true;
    // Seed may have changed while the tray was starting up.
    await _tray.setImage(ThemeSeedIcons.assetPath(_seed));
  }

  @override
  Future<void> setSeedIcon(ThemeSeed seed) async {
    _seed = seed;
    if (!_initialized) return;
    final iconPath = ThemeSeedIcons.assetPath(seed);
    try {
      await _tray.setImage(iconPath);
    } catch (e) {
      log.w('TrayServiceDesktop: setSeedIcon failed for $iconPath', error: e);
    }
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _tray.destroy();
      _initialized = false;
    }
  }
}
