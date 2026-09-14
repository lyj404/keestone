import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Single shared 1-second ticker for every visible TOTP widget, so N tiles
/// don't each own their own [Timer.periodic]. The timer runs only while at
/// least one listener is attached.
///
/// Listeners are always fired outside the build/layout phase. A raw
/// [Timer.periodic] can land mid-build after the wall-clock countdown started
/// updating every second; calling setState then throws and leaves later
/// ListView children unpainted (the "gray hole" under the first few tiles).
class TotpTicker extends ChangeNotifier {
  TotpTicker._();

  static final TotpTicker instance = TotpTicker._();

  Timer? _timer;
  bool _frameCallbackPending = false;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _notifyOutsideBuild(),
    );
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _notifyOutsideBuild() {
    if (!hasListeners) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_frameCallbackPending) return;
    _frameCallbackPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameCallbackPending = false;
      if (hasListeners) notifyListeners();
    });
  }
}
