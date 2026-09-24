import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'logger.dart';

/// Keeps the native window chrome in sync with the in-app theme.
///
/// On Windows the system title bar only follows the OS preference. The
/// runner exposes `keestone/window_theme` so we can force
/// DWMWA_USE_IMMERSIVE_DARK_MODE on the real HWND (and refresh the frame).
/// Do NOT call window_manager.setBrightness on Windows afterwards — its
/// implementation ANDs the request with the OS light/dark flag and will
/// reset a forced-dark title bar back to light when the system is light.
class WindowTitleBar {
  WindowTitleBar._();

  static const MethodChannel _windowsChannel =
      MethodChannel('keestone/window_theme');

  static bool? _lastDark;

  static Future<void> apply(Brightness brightness) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    final dark = brightness == Brightness.dark;
    if (_lastDark == dark) return;

    if (Platform.isWindows) {
      try {
        final reply = await _windowsChannel.invokeMethod<Map<Object?, Object?>>(
          'setTitleBarDark',
          dark,
        );
        _lastDark = dark;
        final hwnd = reply?['hwnd'];
        final readback = reply?['readback'];
        log.d(
          'WindowTitleBar: applied dark=$dark hwnd=0x'
          '${(hwnd is int ? hwnd : 0).toRadixString(16)} readback=$readback',
        );
      } catch (e) {
        log.w('WindowTitleBar: setTitleBarDark failed', error: e);
      }
      return;
    }

    _lastDark = dark;
    try {
      await windowManager.setBrightness(brightness);
    } catch (_) {
      // Non-fatal on platforms without setBrightness support.
    }
  }
}
