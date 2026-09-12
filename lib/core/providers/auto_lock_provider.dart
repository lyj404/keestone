import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../utils/secure_storage_helper.dart';
import 'package:go_router/go_router.dart';
import '../../features/database/providers/database_provider.dart';
import '../router/app_router.dart';

const _lockTimeoutOptions = [0, 1, 5, 15, 30, 60]; // minutes, 0 = disabled

class AutoLockNotifier extends StateNotifier<int> {
  static const _storage = SecureStorageHelper();
  static const _key = 'auto_lock_minutes';
  final Ref _ref;
  Timer? _timer;

  AutoLockNotifier(this._ref) : super(0) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value != null) {
      state = int.tryParse(value) ?? 0;
    }
  }

  Future<void> setMinutes(int minutes) async {
    state = minutes;
    await _storage.write(key: _key, value: minutes.toString());
    resetTimer();
  }

  void resetTimer() {
    _timer?.cancel();
    if (state <= 0) return;
    _timer = Timer(Duration(minutes: state), _lock);
  }

  void cancelTimer() {
    _timer?.cancel();
  }

  void _lock() {
    unawaited(_lockAsync());
  }

  Future<void> _lockAsync() async {
    final dbNotifier = _ref.read(databaseProvider.notifier);
    final dbState = _ref.read(databaseProvider);
    final hasDb = dbState.value != null;
    if (!hasDb) return;

    final lockFuture = dbNotifier.lock();
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.go('/welcome');
    }
    await lockFuture;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final autoLockProvider = StateNotifierProvider<AutoLockNotifier, int>((ref) {
  return AutoLockNotifier(ref);
});

final autoLockTimeoutOptionsProvider = Provider<List<int>>((ref) {
  return _lockTimeoutOptions;
});
