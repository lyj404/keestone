import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

Timer? _clipboardTimer;
int _scheduleGeneration = 0;
List<int>? _lastCopiedMac;
final Uint8List _clipboardMacKey = Uint8List.fromList(
  List<int>.generate(32, (_) => Random.secure().nextInt(256)),
);
final Hmac _clipboardHmac = Hmac.sha256();

Future<List<int>> _mac(String value) async {
  final result = await _clipboardHmac.calculateMac(
    utf8.encode(value),
    secretKey: SecretKey(_clipboardMacKey),
  );
  return result.bytes;
}

bool _constantTimeEquals(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var i = 0; i < left.length; i++) {
    difference |= left[i] ^ right[i];
  }
  return difference == 0;
}

void copyToClipboardWithAutoClear(
  String text, {
  Duration timeout = AppConstants.clipboardClearTimeout,
}) {
  _clipboardTimer?.cancel();
  // Bump the generation so any in-flight (async) _scheduleClear from a
  // previous copy knows it has been superseded and won't arm a stale timer.
  final generation = ++_scheduleGeneration;
  unawaited(Clipboard.setData(ClipboardData(text: text)));
  unawaited(_scheduleClear(text, timeout, generation));
}

Future<void> _scheduleClear(
  String text,
  Duration timeout,
  int generation,
) async {
  final copiedMac = await _mac(text);
  // A newer copy arrived while computing the MAC; don't arm a timer for it.
  if (generation != _scheduleGeneration) return;
  _lastCopiedMac = copiedMac;
  if (timeout.inSeconds <= 0) return;
  _clipboardTimer = Timer(timeout, () async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    final currentText = current?.text;
    if (currentText != null &&
        _constantTimeEquals(await _mac(currentText), copiedMac)) {
      await Clipboard.setData(const ClipboardData(text: ''));
      _lastCopiedMac = null;
    }
  });
}

Future<void> clearClipboardIfCopied() async {
  _clipboardTimer?.cancel();
  final lastMac = _lastCopiedMac;
  if (lastMac == null) return;
  try {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    final currentText = current?.text;
    if (currentText != null &&
        _constantTimeEquals(await _mac(currentText), lastMac)) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  } catch (_) {
    // Clipboard access can fail while an application is shutting down.
  }
  _lastCopiedMac = null;
}
