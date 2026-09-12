import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../utils/secure_storage_helper.dart';

const _storageKey = 'app_locale';

final localeStorageProvider = Provider<SecureStorageHelper>((ref) {
  return const SecureStorageHelper();
});

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier(ref);
});

class LocaleNotifier extends StateNotifier<Locale?> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final code = await _ref.read(localeStorageProvider).read(key: _storageKey);
    if (code == null) return;
    if (code == 'system') {
      state = null;
    } else {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final code = locale?.languageCode ?? 'system';
    await _ref.read(localeStorageProvider).write(key: _storageKey, value: code);
  }
}
