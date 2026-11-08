import 'package:flutter_riverpod/legacy.dart';

import '../../../core/utils/secure_storage_helper.dart';

/// Whether typing a username in the entry editor should offer completions
/// from usernames already present in the vault. Default: enabled.
class UsernameSuggestNotifier extends StateNotifier<bool> {
  static const _storage = SecureStorageHelper();
  static const _key = 'username_suggest_enabled';

  UsernameSuggestNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value != null) state = value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(key: _key, value: enabled.toString());
  }
}

final usernameSuggestProvider =
    StateNotifierProvider<UsernameSuggestNotifier, bool>(
  (ref) => UsernameSuggestNotifier(),
);
