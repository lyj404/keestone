import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import '../data/autotype_sequence.dart';

/// Whether the current platform supports the native side of AutoType.
/// Windows registers the global hotkey and types via SendInput; macOS uses
/// a Carbon hotkey + CGEvent typing (requires Accessibility permission);
/// Linux supports X11 sessions only (Wayland cannot inject input).
bool get autotypePlatformSupported =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Whether the current Linux session runs Wayland, which cannot support
/// AutoType (no input injection / global hotkeys). Always false on other
/// platforms.
bool get autotypeSessionUnsupported {
  if (defaultTargetPlatform != TargetPlatform.linux) return false;
  // Prefer the explicit session-type variable; fall back to the presence
  // of a Wayland socket when it is unset.
  final sessionType = Platform.environment['XDG_SESSION_TYPE'];
  if (sessionType != null && sessionType.isNotEmpty) {
    return sessionType.toLowerCase() == 'wayland';
  }
  return Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty == true;
}

/// Thin wrapper over the native "keestone/autotype" method channel.
class AutoTypeNative {
  static const _channel = MethodChannel('keestone/autotype');

  /// Fires when the global hotkey (Ctrl+Alt+A) is pressed.
  static final _hotkeyStream = StreamController<void>.broadcast();

  static bool _listening = false;

  static Stream<void> get hotkeyPressed {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'hotkeyPressed') {
          _hotkeyStream.add(null);
        }
        return null;
      });
    }
    return _hotkeyStream.stream;
  }

  /// Whether the native side successfully registered the global hotkey.
  /// Returns false on Wayland sessions (X11-only on Linux), when the hotkey
  /// is taken by another app, or when the native handler is missing (e.g.
  /// platform without the channel).
  static Future<bool> isHotkeyRegistered() async {
    if (!autotypePlatformSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isHotkeyRegistered') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> typeText(String text) =>
      _channel.invokeMethod('typeText', text);

  static Future<void> pressKey(String key) =>
      _channel.invokeMethod('pressKey', key);

  static Future<void> clearField() => _channel.invokeMethod('clearField');

  /// Executes a full parsed action list against the native typer.
  static Future<void> performActions(List<AutoTypeAction> actions) =>
      runAutoTypeActions(actions, (action) async {
        switch (action) {
          case TypeText(:final text):
            await typeText(text);
          case PressKey(:final key):
            await pressKey(key);
          case Pause():
            break; // handled inside runAutoTypeActions
          case ClearCurrentField():
            await clearField();
        }
      });
}
