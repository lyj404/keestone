import 'dart:convert';

import '../../../core/utils/password_encryptor.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 'git_config.dart';

/// Persists Git sync profiles in secure storage with AES-GCM-encrypted
/// tokens. Mirrors the write-queue serialization of WebDavSettingsService so
/// concurrent read-modify-write cycles cannot drop a profile.
class GitSettingsService {
  static const _configKey = 'git_sync_profiles';
  final _storage = const SecureStorageHelper();
  final _encryptor = PasswordEncryptor();
  static Future<void> _writeQueue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<GitSyncConfig?> getConfig() async {
    final profiles = await getProfiles();
    return profiles.isEmpty ? null : profiles.first;
  }

  Future<GitSyncConfig?> getConfigById(String? profileId) async {
    final profiles = await getProfiles();
    if (profiles.isEmpty) return null;
    if (profileId == null) return profiles.first;
    for (final profile in profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<List<GitSyncConfig>> getProfiles() async {
    final json = await _storage.read(key: _configKey);
    if (json == null) return const [];
    return await _decodeProfiles(json);
  }

  Future<List<GitSyncConfig>> _decodeProfiles(String json) async {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      final profiles = decoded
          .whereType<Map<String, dynamic>>()
          .map(GitSyncConfig.fromJson)
          .toList();
      return await _decryptTokens(profiles);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveConfig(GitSyncConfig config) {
    return _serialized<void>(() async {
      final profiles = [...await getProfiles()];
      final index = profiles.indexWhere((p) => p.id == config.id);
      if (index >= 0) {
        profiles[index] = config;
      } else {
        profiles.add(config);
      }
      await _persist(profiles);
    });
  }

  Future<void> deleteProfile(String profileId) {
    return _serialized<void>(() async {
      final profiles = await getProfiles();
      await _persist(profiles.where((p) => p.id != profileId).toList());
    });
  }

  Future<List<GitSyncConfig>> _decryptTokens(
    List<GitSyncConfig> profiles,
  ) async {
    final result = <GitSyncConfig>[];
    for (final profile in profiles) {
      if (profile.token.isEmpty) {
        result.add(profile);
        continue;
      }
      try {
        result.add(
          profile.copyWith(token: await _encryptor.decrypt(profile.token)),
        );
      } catch (_) {
        // Unreadable token (device key lost): keep the profile so settings
        // survive, the sync attempt will fail with an auth error instead of
        // silently vanishing.
        result.add(profile);
      }
    }
    return result;
  }

  Future<void> _persist(List<GitSyncConfig> profiles) async {
    final encrypted = <GitSyncConfig>[];
    for (final profile in profiles) {
      encrypted.add(
        profile.token.isEmpty
            ? profile
            : profile.copyWith(token: await _encryptor.encrypt(profile.token)),
      );
    }
    await _storage.write(
      key: _configKey,
      value: jsonEncode(encrypted.map((p) => p.toJson()).toList()),
    );
  }
}
