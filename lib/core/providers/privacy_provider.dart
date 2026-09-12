import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../utils/logger.dart';
import '../utils/secure_storage_helper.dart';

const _privacyChannel = MethodChannel('com.keestone.keestone/privacy');

class PrivacySettings {
  final bool blockScreenshots;
  final bool hideInBackground;

  const PrivacySettings({
    this.blockScreenshots = false,
    this.hideInBackground = false,
  });

  PrivacySettings copyWith({bool? blockScreenshots, bool? hideInBackground}) =>
      PrivacySettings(
        blockScreenshots: blockScreenshots ?? this.blockScreenshots,
        hideInBackground: hideInBackground ?? this.hideInBackground,
      );
}

class PrivacyNotifier extends StateNotifier<PrivacySettings> {
  static const _storage = SecureStorageHelper();
  static const _screenshotKey = 'privacy_block_screenshots';
  static const _backgroundKey = 'privacy_hide_in_background';

  PrivacyNotifier() : super(const PrivacySettings()) {
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      _storage.read(key: _screenshotKey),
      _storage.read(key: _backgroundKey),
    ]);
    state = PrivacySettings(
      blockScreenshots: values[0] == 'true',
      hideInBackground: values[1] == 'true',
    );
    await _applyScreenshotProtection();
  }

  Future<void> setBlockScreenshots(bool enabled) async {
    state = state.copyWith(blockScreenshots: enabled);
    await _storage.write(key: _screenshotKey, value: enabled.toString());
    await _applyScreenshotProtection();
  }

  Future<void> setHideInBackground(bool enabled) async {
    state = state.copyWith(hideInBackground: enabled);
    await _storage.write(key: _backgroundKey, value: enabled.toString());
  }

  Future<void> _applyScreenshotProtection() async {
    if (!Platform.isAndroid) return;
    try {
      await _privacyChannel.invokeMethod<void>(
        'setSecureScreen',
        state.blockScreenshots,
      );
    } on PlatformException catch (error) {
      log.w('Unable to update Android screenshot protection', error: error);
    }
  }
}

final privacyProvider = StateNotifierProvider<PrivacyNotifier, PrivacySettings>(
  (ref) {
    return PrivacyNotifier();
  },
);
