import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'theme/theme_seed.dart';
import 'tray_service_desktop.dart';
import 'tray_service_linux.dart';

abstract class TrayServiceBase {
  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  });

  /// Swap tray icon to match the active [ThemeSeed]. No-op before [init].
  Future<void> setSeedIcon(ThemeSeed seed);
  Future<void> dispose();
}

TrayServiceBase createTrayService() {
  if (Platform.isLinux) return createTrayServiceLinux();
  return createTrayServiceDesktop();
}

class TrayService {
  static final TrayService _instance = TrayService._();
  factory TrayService() => _instance;
  TrayService._();

  TrayServiceBase? _impl;

  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    _impl = createTrayService();
    await _impl!.init(
      showLabel: showLabel,
      exitLabel: exitLabel,
      onShowWindow: onShowWindow,
      onExitApp: onExitApp,
    );
  }

  Future<void> setSeedIcon(ThemeSeed seed) async {
    await _impl?.setSeedIcon(seed);
  }

  Future<void> dispose() async {
    await _impl?.dispose();
  }
}
