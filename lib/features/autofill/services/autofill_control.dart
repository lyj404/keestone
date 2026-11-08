import 'package:flutter/services.dart';

import '../../../core/utils/logger.dart';

const _channel = MethodChannel('com.keestone.keestone/autofill_control');

/// Native bridge for autofill status / system-settings requests.
///
/// `isDefaultService` (Android only) returns whether KeeVault is the system's
/// current autofill provider; `requestSetDefault` opens the system prompt.
class AutofillControl {
  static Future<bool> isDefaultService() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDefaultService');
      return result ?? false;
    } catch (e) {
      log.w('autofill_control.isDefaultService failed', error: e);
      return false;
    }
  }

  static Future<void> requestSetDefault() async {
    try {
      await _channel.invokeMethod<void>('requestSetDefault');
    } catch (e) {
      log.w('autofill_control.requestSetDefault failed', error: e);
    }
  }
}
