import '../../../core/utils/password_encryptor.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 'webdav_config.dart';

class WebDavSettingsService {
  static const _configKey = 'webdav_profiles';
  static const _legacyConfigKey = 'webdav_config';
  final _storage = const SecureStorageHelper();
  final _encryptor = PasswordEncryptor();

  /// Serializes read-modify-write cycles on the profiles state. Concurrent
  /// mutations (e.g. two quick "new profile" actions interleaving) would
  /// otherwise write whole snapshots built from the same stale read, and the
  /// loser's profile would be dropped.
  static Future<void> _writeQueue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    // Keep the chain alive even when an action fails.
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<WebDavConfig?> getConfig() async {
    return (await getProfilesState()).activeProfile;
  }

  Future<WebDavConfig?> getConfigById(String? profileId) async {
    final state = await getProfilesState();
    if (profileId == null) return state.activeProfile;
    for (final profile in state.profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<WebDavProfilesState> getProfilesState() async {
    final json = await _storage.read(key: _configKey);
    if (json != null) {
      final stored = WebDavProfilesState.decode(json);
      final decrypted = await _decryptProfilesState(stored);
      // Migrate legacy XOR-encrypted passwords and any still-plaintext
      // passwords to AES-GCM in storage.
      final needsUpgrade = stored.profiles.any(
        (p) =>
            p.password.isNotEmpty &&
            !_encryptor.isEncrypted(p.password),
      );
      if (needsUpgrade) {
        await _persistState(decrypted);
      }
      return decrypted;
    }

    final legacyJson = await _storage.read(key: _legacyConfigKey);
    if (legacyJson == null) {
      return const WebDavProfilesState(profiles: [], activeProfileId: null);
    }

    final legacyConfig = WebDavConfig.decode(
      legacyJson,
    ).copyWith(id: 'webdav_legacy', name: 'Default');
    final migrated = WebDavProfilesState(
      profiles: [legacyConfig],
      activeProfileId: legacyConfig.id,
    );
    // Persist the migrated state directly. Calling saveConfig here would call
    // getProfilesState again while the legacy key still exists, causing an
    // endless getProfilesState -> saveConfig recursion.
    final decrypted = await _decryptProfilesState(migrated);
    await _persistState(decrypted);
    await _storage.delete(key: _legacyConfigKey);
    return decrypted;
  }

  Future<void> saveConfig(WebDavConfig config) {
    return _serialized(() async {
      final state = await getProfilesState();
      final profiles = [...state.profiles];
      final index = profiles.indexWhere((profile) => profile.id == config.id);
      if (index >= 0) {
        profiles[index] = config;
      } else {
        profiles.add(config);
      }
      await _persistState(
        WebDavProfilesState(profiles: profiles, activeProfileId: config.id),
      );
    });
  }

  Future<void> deleteConfig() async {
    await _storage.delete(key: _legacyConfigKey);
    await _storage.delete(key: _configKey);
  }

  Future<void> deleteProfile(String profileId) {
    return _serialized(() async {
      final state = await getProfilesState();
      final profiles = state.profiles
          .where((profile) => profile.id != profileId)
          .toList();
      final nextActive = state.activeProfileId == profileId
          ? (profiles.isEmpty ? null : profiles.first.id)
          : state.activeProfileId;
      await _persistState(
        WebDavProfilesState(profiles: profiles, activeProfileId: nextActive),
      );
    });
  }

  Future<void> setActiveProfile(String profileId) {
    return _serialized(() async {
      final state = await getProfilesState();
      final exists = state.profiles.any((profile) => profile.id == profileId);
      if (!exists) return;
      await _persistState(
        WebDavProfilesState(
          profiles: state.profiles,
          activeProfileId: profileId,
        ),
      );
    });
  }

  /// Encrypts the password in a [WebDavConfig] before storage.
  Future<WebDavConfig> _encryptConfig(WebDavConfig config) async {
    if (config.password.isEmpty) return config;
    final encrypted = await _encryptor.encrypt(config.password);
    return config.copyWith(password: encrypted);
  }

  /// Encrypts all profile passwords and writes the state to storage.
  Future<void> _persistState(WebDavProfilesState state) async {
    final encryptedProfiles = <WebDavConfig>[];
    for (final profile in state.profiles) {
      encryptedProfiles.add(await _encryptConfig(profile));
    }
    final updated = WebDavProfilesState(
      profiles: encryptedProfiles,
      activeProfileId: state.activeProfileId,
    );
    await _storage.write(key: _configKey, value: updated.encode());
  }

  /// Decrypts passwords in a [WebDavProfilesState] after loading.
  Future<WebDavProfilesState> _decryptProfilesState(
    WebDavProfilesState state,
  ) async {
    final decryptedProfiles = <WebDavConfig>[];
    for (final profile in state.profiles) {
      if (profile.password.isNotEmpty) {
        final decrypted = await _encryptor.decrypt(profile.password);
        decryptedProfiles.add(profile.copyWith(password: decrypted));
      } else {
        decryptedProfiles.add(profile);
      }
    }
    return WebDavProfilesState(
      profiles: decryptedProfiles,
      activeProfileId: state.activeProfileId,
    );
  }
}
