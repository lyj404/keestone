import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage backend abstraction for secrets (WebDAV credentials, settings).
///
/// The default backend is the flutter_secure_storage plugin. On Linux the app
/// swaps in [LinuxChannelSecureStore] at startup: the plugin's libsecret
/// implementation matches keyring items by their `xdg:schema` attribute, which
/// KDE's ksecretd does not honor, so plugin reads silently fail on those
/// systems (https://github.com/mogol/flutter_secure_storage issues). The
/// runner-level backend matches items by plain attributes instead, which
/// works on both gnome-keyring and ksecretd.
abstract class SecureStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String? value});

  Future<void> delete({required String key});

  Future<Map<String, String>> readAll();
}

class PluginSecureStore implements SecureStore {
  final FlutterSecureStorage _storage;

  const PluginSecureStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}

/// Reads older data-protection Keychain entries when accessible, and moves
/// them to the macOS file-based Keychain used by ad-hoc signed builds.
class MacOSMigratingSecureStore implements SecureStore {
  final SecureStore current;
  final SecureStore previous;

  const MacOSMigratingSecureStore(this.current, this.previous);

  bool _missingEntitlement(Object error) =>
      error is PlatformException &&
      (error.code == '-34018' ||
          error.details == -34018 ||
          error.message?.contains('-34018') == true);

  Future<T?> _old<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (_missingEntitlement(error)) return null;
      rethrow;
    }
  }

  /// Read without migrating: callers must authenticate data before using an
  /// older key, because the two Keychains can contain unrelated generations.
  Future<String?> readPrevious({required String key}) =>
      _old<String?>(() => previous.read(key: key));

  @override
  Future<String?> read({required String key}) async {
    final value = await current.read(key: key);
    if (value != null) return value;
    final old = await _old(() => previous.read(key: key));
    if (old != null) {
      await current.write(key: key, value: old);
      await _old(() => previous.delete(key: key));
    }
    return old;
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) return delete(key: key);
    await current.write(key: key, value: value);
    await _old(() => previous.delete(key: key));
  }

  @override
  Future<void> delete({required String key}) async {
    await _old(() => previous.delete(key: key));
    await current.delete(key: key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    final old = await _old(previous.readAll) ?? {};
    final values = await current.readAll();
    for (final entry in old.entries) {
      if (!values.containsKey(entry.key)) {
        await current.write(key: entry.key, value: entry.value);
        values[entry.key] = entry.value;
      }
      await _old(() => previous.delete(key: entry.key));
    }
    return values;
  }
}

class LinuxChannelSecureStore implements SecureStore {
  static const _channel = MethodChannel('keestone/secure_storage');

  @override
  Future<String?> read({required String key}) =>
      _channel.invokeMethod<String>('read', {'key': key});

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      await delete(key: key);
      return;
    }
    await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
  }

  @override
  Future<void> delete({required String key}) =>
      _channel.invokeMethod<void>('delete', {'key': key});

  @override
  Future<Map<String, String>> readAll() async {
    final raw = await _channel.invokeMethod<Object?>('readAll');
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k! as String, v! as String));
  }
}

SecureStore? _defaultBackend;

/// Backend used when no explicit one is injected. Defaults to the plugin so
/// tests stay hermetic; [initSecureStoreBackend] swaps in the Linux runner
/// backend at app startup.
SecureStore get defaultSecureStore =>
    _defaultBackend ??= const PluginSecureStore();

set defaultSecureStore(SecureStore store) => _defaultBackend = store;

/// Called once from main() before any service is constructed.
void initSecureStoreBackend() {
  if (Platform.isLinux) {
    defaultSecureStore = LinuxChannelSecureStore();
  } else if (Platform.isMacOS) {
    defaultSecureStore = const MacOSMigratingSecureStore(
      PluginSecureStore(
        FlutterSecureStorage(
          mOptions: MacOsOptions(usesDataProtectionKeychain: false),
        ),
      ),
      PluginSecureStore(),
    );
  }
}
