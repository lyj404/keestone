import 'package:flutter_riverpod/legacy.dart';
import '../utils/secure_storage_helper.dart';

/// What happens when the user clicks the window close button.
enum CloseBehavior {
  /// Show a dialog every time asking exit or minimize.
  ask,

  /// Always minimize to system tray.
  minimizeToTray,

  /// Always exit the application.
  exit,
}

final closeBehaviorProvider = StateNotifierProvider<CloseBehaviorNotifier, CloseBehavior>((ref) {
  return CloseBehaviorNotifier();
});

class CloseBehaviorNotifier extends StateNotifier<CloseBehavior> {
  static const _storage = SecureStorageHelper();
  static const _key = 'close_behavior';
  Future<void>? _loading;

  CloseBehaviorNotifier() : super(CloseBehavior.ask) {
    _loading = _load();
  }

  /// Awaits the initial load so window-close handling never acts on the
  /// default value before the persisted preference has been read.
  Future<void> ensureLoaded() => _loading ?? Future.value();

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value == 'exit') {
      state = CloseBehavior.exit;
    } else if (value == 'minimizeToTray') {
      state = CloseBehavior.minimizeToTray;
    } else {
      state = CloseBehavior.ask;
    }
  }

  Future<void> setCloseBehavior(CloseBehavior behavior) async {
    state = behavior;
    await _storage.write(key: _key, value: behavior.name);
  }
}
