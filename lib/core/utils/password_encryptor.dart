import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'secure_store.dart';

/// Encrypts and decrypts WebDAV passwords using AES-256-GCM
/// with a device-bound key stored in secure storage.
///
/// Legacy formats are still readable:
/// - `ENC:` prefix — old XOR scheme (cryptographically weak, decrypt-only)
/// - no prefix — plaintext
/// Both are transparently migrated to `ENC2:` when re-encrypted.
class PasswordDecryptionException implements Exception {
  final String format;
  final Object? cause;

  const PasswordDecryptionException(this.format, [this.cause]);

  @override
  String toString() => 'PasswordDecryptionException($format)';
}

class PasswordEncryptor {
  static const _keyStorageName = 'webdav_enc_key';
  static const _legacyIvLength = 16;

  /// Marker for the current AES-GCM format.
  static const encryptedMarker = 'ENC2:';

  /// Marker for the legacy XOR format (decrypt-only).
  static const legacyEncryptedMarker = 'ENC:';

  static final _aesGcm = AesGcm.with256bits();

  /// In-flight key creation, shared across instances. Two concurrent
  /// first-time encryptions must not each generate a key: the last write to
  /// secure storage would win and data encrypted with the loser's key could
  /// never be decrypted again.
  static Future<Uint8List>? _keyCreation;

  final SecureStore _storage;
  Uint8List? _cachedKey;

  PasswordEncryptor([SecureStore? storage])
    : _storage = storage ?? defaultSecureStore;

  /// Returns the device-bound encryption key, generating one if needed.
  Future<Uint8List> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final inFlight = _keyCreation;
    if (inFlight != null) {
      final key = await inFlight;
      return _cachedKey ?? key;
    }
    final creation = _readOrCreateKey();
    _keyCreation = creation;
    try {
      final key = await creation;
      _cachedKey = key;
      return key;
    } finally {
      if (identical(_keyCreation, creation)) _keyCreation = null;
    }
  }

  Future<Uint8List> _readOrCreateKey() async {
    final existing = await _storage.read(key: _keyStorageName);
    if (existing != null) {
      return base64Url.decode(existing);
    }
    final random = Random.secure();
    final key = Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
    await _storage.write(key: _keyStorageName, value: base64Url.encode(key));
    return key;
  }

  /// Returns true if the password is encrypted in the current format.
  bool isEncrypted(String password) => password.startsWith(encryptedMarker);

  /// Returns true if the password is encrypted in the legacy XOR format.
  bool isLegacyEncrypted(String password) =>
      password.startsWith(legacyEncryptedMarker) && !isEncrypted(password);

  /// Encrypts a plaintext password with AES-256-GCM. Returns a string with
  /// the ENC2: prefix followed by base64url of nonce+ciphertext+tag.
  /// Legacy-encrypted input is decrypted first and re-encrypted.
  Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return '';
    if (isEncrypted(plaintext)) return plaintext;
    if (isLegacyEncrypted(plaintext)) {
      plaintext = await decrypt(plaintext);
      if (plaintext.isEmpty) return '';
    }

    final key = await _getOrCreateKey();
    final secretKey = SecretKey(key);
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );
    final combined = secretBox.concatenation(); // nonce + ciphertext + mac
    return '$encryptedMarker${base64Url.encode(combined)}';
  }

  /// Decrypts an encrypted password string. Supports the current AES-GCM
  /// format, the legacy XOR format, and plaintext (returned as-is).
  /// Throws [PasswordDecryptionException] if encrypted data is malformed,
  /// tampered with, or cannot be decrypted using the device key.
  Future<String> decrypt(String encryptedPassword) async {
    if (encryptedPassword.isEmpty) return '';
    if (isEncrypted(encryptedPassword)) {
      return _decryptAesGcm(encryptedPassword);
    }
    if (isLegacyEncrypted(encryptedPassword)) {
      return _decryptLegacyXor(encryptedPassword);
    }
    return encryptedPassword;
  }

  Future<String> _decryptAesGcm(String encryptedPassword) async {
    try {
      final data = base64Url.decode(
        encryptedPassword.substring(encryptedMarker.length),
      );
      final key = await _getOrCreateKey();
      final secretBox = SecretBox.fromConcatenation(
        data,
        nonceLength: AesGcm.defaultNonceLength,
        macLength: 16,
      );
      final clear = await _aesGcm.decrypt(secretBox, secretKey: SecretKey(key));
      return utf8.decode(clear);
    } catch (error) {
      throw PasswordDecryptionException('aes-gcm', error);
    }
  }

  Future<String> _decryptLegacyXor(String encryptedPassword) async {
    try {
      final base64Data = encryptedPassword.substring(
        legacyEncryptedMarker.length,
      );
      final key = await _getOrCreateKey();
      final data = base64Url.decode(base64Data);

      if (data.length <= _legacyIvLength) {
        throw const PasswordDecryptionException('legacy-xor');
      }

      final iv = data.sublist(0, _legacyIvLength);
      final ciphertext = data.sublist(_legacyIvLength);

      final decrypted = Uint8List(ciphertext.length);
      for (var i = 0; i < ciphertext.length; i++) {
        final k = key[i % key.length] ^ iv[i % iv.length];
        decrypted[i] = ciphertext[i] ^ k;
      }
      return utf8.decode(decrypted);
    } on PasswordDecryptionException {
      rethrow;
    } catch (error) {
      throw PasswordDecryptionException('legacy-xor', error);
    }
  }
}
