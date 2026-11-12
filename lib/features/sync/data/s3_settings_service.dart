import 'dart:convert';

import '../../../core/utils/password_encryptor.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 's3_config.dart';

/// Persists S3 sync profiles in secure storage with AES-GCM-encrypted
/// secrets. Mirrors the write-queue serialization of GitSettingsService so
/// concurrent read-modify-write cycles cannot drop a profile.
class S3SettingsService {
  static const _configKey = 's3_sync_profiles';
  final _storage = const SecureStorageHelper();
  final _encryptor = PasswordEncryptor();
  static Future<void> _writeQueue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writeQueue.then((_) => action());
    _writeQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<S3SyncConfig?> getConfig() async {
    final profiles = await getProfiles();
    return profiles.isEmpty ? null : profiles.first;
  }

  Future<S3SyncConfig?> getConfigById(String? profileId) async {
    final profiles = await getProfiles();
    if (profiles.isEmpty) return null;
    if (profileId == null) return profiles.first;
    for (final profile in profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<List<S3SyncConfig>> getProfiles() async {
    final json = await _storage.read(key: _configKey);
    if (json == null) return const [];
    return await _decodeProfiles(json);
  }

  Future<List<S3SyncConfig>> _decodeProfiles(String json) async {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      final profiles = decoded
          .whereType<Map<String, dynamic>>()
          .map(S3SyncConfig.fromJson)
          .toList();
      return await _decryptSecrets(profiles);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveConfig(S3SyncConfig config) {
    return _serialized<void>(() async {
      final profiles = [...await getProfiles()];
      final index = profiles.indexWhere((p) => p.id == config.id);
      if (index >= 0) {
        profiles[index] = config;
      } else {
        profiles.add(config);
      }
      await _persistProfiles(profiles);
    });
  }

  Future<void> deleteProfile(String profileId) {
    return _serialized<void>(() async {
      final profiles = (await getProfiles())
          .where((p) => p.id != profileId)
          .toList();
      await _persistProfiles(profiles);
    });
  }

  /// Encrypts secrets in a [S3SyncConfig] before storage.
  Future<S3SyncConfig> _encryptConfig(S3SyncConfig config) async {
    var updated = config;
    if (config.secretAccessKey.isNotEmpty &&
        !_encryptor.isEncrypted(config.secretAccessKey)) {
      updated = updated.copyWith(
        secretAccessKey: await _encryptor.encrypt(config.secretAccessKey),
      );
    }
    if (config.sessionToken.isNotEmpty &&
        !_encryptor.isEncrypted(config.sessionToken)) {
      updated = updated.copyWith(
        sessionToken: await _encryptor.encrypt(config.sessionToken),
      );
    }
    return updated;
  }

  Future<void> _persistProfiles(List<S3SyncConfig> profiles) async {
    final encrypted = <S3SyncConfig>[];
    for (final profile in profiles) {
      encrypted.add(await _encryptConfig(profile));
    }
    await _storage.write(
      key: _configKey,
      value: jsonEncode(encrypted.map((p) => p.toJson()).toList()),
    );
  }

  Future<List<S3SyncConfig>> _decryptSecrets(List<S3SyncConfig> profiles) async {
    final decrypted = <S3SyncConfig>[];
    for (final profile in profiles) {
      var updated = profile;
      if (profile.secretAccessKey.isNotEmpty &&
          _encryptor.isEncrypted(profile.secretAccessKey)) {
        try {
          updated = updated.copyWith(
            secretAccessKey: await _encryptor.decrypt(
              profile.secretAccessKey,
            ),
          );
        } catch (_) {
          // A secret that fails to decrypt (key change, corrupt record) must
          // not take the whole profile list down; keep it and let the sync
          // request fail with an auth error instead.
        }
      }
      if (profile.sessionToken.isNotEmpty &&
          _encryptor.isEncrypted(profile.sessionToken)) {
        try {
          updated = updated.copyWith(
            sessionToken: await _encryptor.decrypt(profile.sessionToken),
          );
        } catch (_) {}
      }
      decrypted.add(updated);
    }
    return decrypted;
  }
}
