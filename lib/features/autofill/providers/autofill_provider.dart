import 'package:flutter_riverpod/legacy.dart';

import '../../../core/utils/secure_storage_helper.dart';

const _key = 'autofill_enabled';

/// Whether the mobile autofill integration is enabled by the user.
///
/// When true (and the platform supports it) the native autofill service is
/// expected to be active; the app also writes an autofill credential snapshot
/// (iOS) on unlock. Defaults to false until the user opts in from Settings.
class AutofillEnabledNotifier extends StateNotifier<bool> {
  static const _storage = SecureStorageHelper();

  AutofillEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    state = value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(key: _key, value: enabled.toString());
  }
}

final autofillEnabledProvider =
    StateNotifierProvider<AutofillEnabledNotifier, bool>((ref) {
      return AutofillEnabledNotifier();
    });
