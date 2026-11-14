import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;

import 'theme/theme_seed.dart';
import 'theme/theme_seed_icons.dart';
import 'utils/logger.dart';

class TrayService {
  static final TrayService _instance = TrayService._();
  factory TrayService() => _instance;
  TrayService._();

  tray.TrayIcon? _icon;
  tray.Menu? _menu;
  tray.MenuItem? _showItem;
  tray.MenuItem? _exitItem;
  ThemeSeed _seed = ThemeSeed.slate;

  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_icon != null) return;

    try {
      final icon = tray.TrayIcon.createWithIdentifier('keestone');
      if (icon == null) throw StateError('Could not create tray icon');
      _icon = icon;
      // On Linux a newly created icon is visible only if D-Bus setup succeeded.
      if (Platform.isLinux && !icon.isVisible()) {
        throw StateError('Could not connect tray icon to D-Bus');
      }

      final menu = tray.Menu.create();
      if (menu == null) throw StateError('Could not create tray menu');
      _menu = menu;
      final showItem = tray.MenuItem.createWithLabelAndType(
        showLabel,
        tray.MenuItemType.normal,
      );
      if (showItem == null) throw StateError('Could not create show menu item');
      _showItem = showItem;
      final exitItem = tray.MenuItem.createWithLabelAndType(
        exitLabel,
        tray.MenuItemType.normal,
      );
      if (exitItem == null) throw StateError('Could not create exit menu item');
      _exitItem = exitItem;

      showItem.addListener((event) {
        if (event is tray.MenuItemClickedEvent) onShowWindow();
      });
      exitItem.addListener((event) {
        if (event is tray.MenuItemClickedEvent) onExitApp();
      });
      menu.addItem(showItem);
      menu.addSeparator();
      menu.addItem(exitItem);
      icon.setContextMenu(menu);
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent ||
            event is tray.TrayIconDoubleClickedEvent) {
          onShowWindow();
        }
      });
      _setIcon(icon, _seed);
      icon.setTooltip('KeeStone');
      if (!icon.setVisible(true)) {
        throw StateError('Could not show tray icon');
      }
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  Future<void> setSeedIcon(ThemeSeed seed) async {
    _seed = seed;
    final icon = _icon;
    if (icon == null) return;
    try {
      _setIcon(icon, seed);
    } catch (e) {
      log.w('TrayService: failed to update icon', error: e);
    }
  }

  void _setIcon(tray.TrayIcon icon, ThemeSeed seed) {
    final path = ThemeSeedIcons.assetPath(seed);
    final image = tray.ImageAsset.fromAsset(path);
    if (image == null) throw StateError('Could not load tray icon: $path');
    try {
      icon.icon = image;
    } finally {
      image.dispose();
    }
  }

  Future<void> dispose() async {
    _icon?.dispose();
    _icon = null;
    _menu?.dispose();
    _menu = null;
    _showItem?.dispose();
    _showItem = null;
    _exitItem?.dispose();
    _exitItem = null;
  }
}
