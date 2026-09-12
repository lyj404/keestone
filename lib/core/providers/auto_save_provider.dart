import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../utils/logger.dart';
import '../utils/secure_storage_helper.dart';
import '../../features/database/providers/database_provider.dart';

const autoSaveDelayOptions = [0, 15, 30, 60, 120, 300]; // seconds, 0 = disabled

class AutoSaveNotifier extends StateNotifier<int> {
  static const _storage = SecureStorageHelper();
  static const _key = 'auto_save_seconds';
  final Ref _ref;
  Timer? _idleTimer;
  Timer? _maxTimer;

  AutoSaveNotifier(this._ref) : super(0) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value != null) {
      state = int.tryParse(value) ?? 0;
    }
  }

  Future<void> setSeconds(int seconds) async {
    state = seconds;
    await _storage.write(key: _key, value: seconds.toString());
    _cancelTimers();
    _scheduleIdle();
  }

  /// User activity postpones only the idle deadline. The hard max deadline
  /// armed when the database became dirty keeps running, so a continuously
  /// interacting user still gets periodic saves instead of never saving.
  void resetTimer() {
    _idleTimer?.cancel();
    _scheduleIdle();
  }

  /// The database became dirty: arm the idle deadline and a hard max deadline
  /// counted from now, so dirty data is persisted within [state] seconds no
  /// matter how much the user keeps interacting.
  void onDirty() {
    resetTimer();
    if (state <= 0) return;
    if (!_hasOpenDirtyDb) return;
    _maxTimer ??= Timer(Duration(seconds: state), _save);
  }

  bool get _hasOpenDirtyDb {
    final dbState = _ref.read(databaseProvider);
    return dbState.value != null && _ref.read(isDirtyProvider);
  }

  void _scheduleIdle() {
    if (state <= 0) return;
    if (!_hasOpenDirtyDb) return;
    _idleTimer = Timer(Duration(seconds: state), _save);
  }

  Future<void> _save() async {
    _cancelTimers();
    if (state <= 0 || !_hasOpenDirtyDb) return;

    try {
      final success = await _ref.read(databaseProvider.notifier).save();
      if (!success) {
        // Cloud conflict or sync error; syncStateProvider drives the UI.
        log.w('Auto-save completed locally but cloud sync did not succeed');
      }
      // A mutation that lands while serialization is running keeps the dirty
      // flag set (the saved bytes do not include it). Re-arm both deadlines
      // so the pending change is persisted even without further activity.
      if (_hasOpenDirtyDb) {
        onDirty();
      }
    } catch (e) {
      log.w('Auto-save failed, retrying once', error: e);
      onDirty();
    }
  }

  void _cancelTimers() {
    _idleTimer?.cancel();
    _maxTimer?.cancel();
    _maxTimer = null;
  }

  void cancelTimer() => _cancelTimers();

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

final autoSaveProvider = StateNotifierProvider<AutoSaveNotifier, int>((ref) {
  return AutoSaveNotifier(ref);
});

final autoSaveDelayOptionsProvider = Provider<List<int>>((ref) {
  return autoSaveDelayOptions;
});
