import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../theme/theme_seed.dart';
import '../utils/secure_storage_helper.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _storage = SecureStorageHelper();
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value == 'light') {
      state = ThemeMode.light;
    } else if (value == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _key, value: mode.name);
  }
}

final themeSeedProvider = StateNotifierProvider<ThemeSeedNotifier, ThemeSeed>((ref) {
  return ThemeSeedNotifier();
});

class ThemeSeedNotifier extends StateNotifier<ThemeSeed> {
  static const _storage = SecureStorageHelper();
  static const _key = 'theme_seed';

  ThemeSeedNotifier() : super(ThemeSeed.indigo) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    state = ThemeSeed.fromId(value);
  }

  Future<void> setThemeSeed(ThemeSeed seed) async {
    state = seed;
    await _storage.write(key: _key, value: seed.name);
  }
}
