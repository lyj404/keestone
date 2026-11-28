import 'dart:convert';
import 'dart:typed_data';

import 'package:kpasslib/kpasslib.dart';
import 'package:otp/otp.dart';

import '../../../core/constants/app_constants.dart';

class TotpConfig {
  final String secret;
  final int period;
  final int digits;
  final String algorithm;
  final String? issuer;
  final String? accountName;

  const TotpConfig({
    required this.secret,
    this.period = 30,
    this.digits = 6,
    this.algorithm = 'SHA1',
    this.issuer,
    this.accountName,
  });

  Algorithm get otpAlgorithm {
    switch (algorithm.toUpperCase()) {
      case 'SHA256':
      case 'HMAC-SHA-256':
        return Algorithm.SHA256;
      case 'SHA512':
      case 'HMAC-SHA-512':
        return Algorithm.SHA512;
      default:
        return Algorithm.SHA1;
    }
  }
}

class TotpService {
  // KeePass 2.x entry-string fields (Advanced tab / TIMEOTP placeholder).
  static const _kSecret = 'TimeOtp-Secret';
  static const _kSecretBase32 = 'TimeOtp-Secret-Base32';
  static const _kSecretHex = 'TimeOtp-Secret-Hex';
  static const _kSecretBase64 = 'TimeOtp-Secret-Base64';
  static const _kPeriod = 'TimeOtp-Period';
  // KeePass uses Length; this app historically wrote Size. Read both.
  static const _kLength = 'TimeOtp-Length';
  static const _kSize = 'TimeOtp-Size';
  static const _kAlgorithm = 'TimeOtp-Algorithm';
  static const _kTotpField = 'TOTP';

  bool hasTotp(KdbxEntry entry) => loadFromEntry(entry) != null;

  TotpConfig? loadFromEntry(KdbxEntry entry) {
    final fromFields = _fieldSecretSource(entry);
    final fields = fromFields == null
        ? null
        : _timeOtpConfig(
            _normalizeSecret(fromFields.value, fromFields.encoding),
            (key) => _readString(entry, key),
          );
    return fields ??
        _loadLegacyCustomData(entry) ??
        _otpAuthFromField(entry, _kTotpField) ??
        _otpAuthFromField(entry, AppConstants.otpField) ??
        _loadSeedFields(entry);
  }

  TotpConfig? _timeOtpConfig(String? secret, String? Function(String) read) =>
      _validatedConfig(
        secret: secret,
        period: read(_kPeriod),
        digits: read(_kLength) ?? read(_kSize),
        algorithm: read(_kAlgorithm),
      );

  TotpConfig? _loadLegacyCustomData(KdbxEntry entry) {
    final data = entry.customData;
    final raw = data?.map[_kSecret]?.value;
    if (raw == null) return null;
    return _timeOtpConfig(
      _normalizeSecret(raw, _SecretEncoding.base32),
      (key) => _readString(entry, key) ?? data?.map[key]?.value,
    );
  }

  TotpConfig? _loadSeedFields(KdbxEntry entry) {
    final raw = _readString(entry, AppConstants.totpSeedField);
    if (raw == null) return null;
    final settings = _readString(
      entry,
      AppConstants.totpSettingsField,
    )?.split(';');
    if (settings != null && settings.length != 2) return null;
    return _validatedConfig(
      secret: _normalizeSecret(raw, _SecretEncoding.base32),
      period: settings?[0],
      digits: settings?[1],
    );
  }

  /// Copies a TOTP that only lives in this app's legacy [KdbxCustomData]
  /// keys into KeePass standard entry fields (`TimeOtp-Secret-Base32` etc.).
  ///
  /// Returns true when [entry] was modified. Safe to call after open; no-op
  /// when the entry already has a standard field secret.
  bool migrateLegacyTotp(KdbxEntry entry) {
    final cd = entry.customData;
    if (cd == null) return false;
    final legacySecret = cd.map[_kSecret]?.value;
    if (legacySecret == null || legacySecret.isEmpty) return false;
    if (_fieldSecretSource(entry) != null) return false;

    final config = _loadLegacyCustomData(entry);
    if (config == null) return false;
    saveToEntry(entry, config);
    return true;
  }

  /// Writes TOTP into KeePass standard entry fields, and mirrors the same
  /// values into legacy customData so builds that still only read customData
  /// keep working against this database.
  void saveToEntry(KdbxEntry entry, TotpConfig config) {
    final secretB32 =
        _normalizeSecret(config.secret, _SecretEncoding.base32) ??
        config.secret;
    entry.fields[_kSecretBase32] = KdbxTextField.fromText(
      text: secretB32,
      protected: true,
    );
    entry.fields[_kPeriod] = KdbxTextField.fromText(
      text: config.period.toString(),
    );
    entry.fields[_kLength] = KdbxTextField.fromText(
      text: config.digits.toString(),
    );
    entry.fields[_kAlgorithm] = KdbxTextField.fromText(
      text: _toKeePassAlgorithm(config.algorithm),
    );

    entry.customData ??= KdbxCustomData();
    final cd = entry.customData!;
    cd.map[_kSecret] = KdbxCustomItem(value: secretB32);
    cd.map[_kPeriod] = KdbxCustomItem(value: config.period.toString());
    cd.map[_kSize] = KdbxCustomItem(value: config.digits.toString());
    cd.map[_kAlgorithm] = KdbxCustomItem(
      value: _toKeePassAlgorithm(config.algorithm),
    );
  }

  void replaceInEntry(KdbxEntry entry, TotpConfig config) {
    final uriField = [
      for (final key in [AppConstants.otpField, _kTotpField])
        if (_otpAuthFromField(entry, key) != null) key,
      if (!entry.fields.containsKey(AppConstants.otpField) &&
          _loadSeedFields(entry) != null)
        AppConstants.otpField,
    ].firstOrNull;
    removeFromEntry(entry);
    if (uriField == null) {
      saveToEntry(entry, config);
      return;
    }

    final account = config.accountName ?? _readString(entry, 'Title') ?? '';
    final issuer = config.issuer;
    final uri = Uri(
      scheme: 'otpauth',
      host: 'totp',
      pathSegments: [issuer == null ? account : '$issuer:$account'],
      queryParameters: {
        'secret': config.secret,
        'period': config.period.toString(),
        'digits': config.digits.toString(),
        'algorithm': toOtpAuthAlgorithm(config.algorithm),
        'issuer': ?issuer,
      },
    );
    entry.fields[uriField] = KdbxTextField.fromText(
      text: uri.toString(),
      protected: true,
    );
  }

  void removeFromEntry(KdbxEntry entry) {
    for (final key in [_kTotpField, AppConstants.otpField]) {
      if (_otpAuthFromField(entry, key) != null) entry.fields.remove(key);
    }
    if (_loadSeedFields(entry) != null) {
      entry.fields.remove(AppConstants.totpSeedField);
      entry.fields.remove(AppConstants.totpSettingsField);
    }
    for (final key in [
      _kSecretBase32,
      _kSecretHex,
      _kSecretBase64,
      _kSecret,
      _kPeriod,
      _kLength,
      _kSize,
      _kAlgorithm,
    ]) {
      entry.fields.remove(key);
    }
    final cd = entry.customData;
    if (cd == null) return;
    cd.map.remove(_kSecret);
    cd.map.remove(_kPeriod);
    cd.map.remove(_kSize);
    cd.map.remove(_kAlgorithm);
  }

  String generateCode(TotpConfig config, {DateTime? at}) {
    final now = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final secret =
        _normalizeSecret(config.secret, _SecretEncoding.base32) ??
        config.secret;
    return OTP.generateTOTPCodeString(
      secret,
      now,
      length: config.digits,
      interval: config.period,
      algorithm: config.otpAlgorithm,
      isGoogle: true,
    );
  }

  /// Seconds left in the current TOTP window, in [1, period].
  ///
  /// Must use the wall clock — `OTP.remainingSeconds` reads the package's
  /// static `lastUsedTime`, which only advances when a code is generated,
  /// so a pure countdown would freeze until the next HMAC.
  int remainingSeconds(TotpConfig config, {DateTime? at}) {
    final nowSec = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return config.period - (nowSec % config.period);
  }

  int timeWindow(TotpConfig config, DateTime at) =>
      at.millisecondsSinceEpoch ~/ (config.period * 1000);

  TotpConfig? parseUri(String input) {
    final uri = input.trim();
    if (uri.startsWith('otpauth://')) {
      return _parseOtpAuthUri(uri);
    }
    return _validatedConfig(
      secret: _normalizeSecret(uri, _SecretEncoding.base32),
    );
  }

  TotpConfig? _otpAuthFromField(KdbxEntry entry, String key) {
    final raw = _readString(entry, key);
    return raw == null ? null : _parseOtpAuthUri(raw);
  }

  ({String value, _SecretEncoding encoding})? _fieldSecretSource(
    KdbxEntry entry,
  ) {
    String? text(String key) {
      final v = entry.fields[key]?.text;
      if (v == null) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final b32 = text(_kSecretBase32);
    if (b32 != null) return (value: b32, encoding: _SecretEncoding.base32);
    final hex = text(_kSecretHex);
    if (hex != null) return (value: hex, encoding: _SecretEncoding.hex);
    final b64 = text(_kSecretBase64);
    if (b64 != null) return (value: b64, encoding: _SecretEncoding.base64);
    // KeePass: TimeOtp-Secret uses the UTF-8 bytes of the value as the key.
    final raw = text(_kSecret);
    if (raw != null) return (value: raw, encoding: _SecretEncoding.utf8);
    return null;
  }

  String? _readString(KdbxEntry entry, String key) {
    final v = entry.fields[key]?.text;
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  /// Converts any supported secret encoding into the Base32 form required
  /// by the `otp` package. Returns null when the payload cannot be decoded.
  String? _normalizeSecret(String secret, _SecretEncoding encoding) {
    try {
      final cleaned = secret
          .replaceAll(' ', '')
          .replaceAll('\n', '')
          .replaceAll('-', '');
      switch (encoding) {
        case _SecretEncoding.base32:
          final stripped = cleaned
              .replaceFirst(RegExp(r'=+$'), '')
              .toUpperCase();
          if (stripped.isEmpty) return null;
          if (!_looksLikeBase32(stripped)) return null;
          return stripped;
        case _SecretEncoding.hex:
          final bytes = _hexDecode(cleaned);
          if (bytes == null || bytes.isEmpty) return null;
          return _base32Encode(bytes);
        case _SecretEncoding.base64:
          final bytes = base64.decode(cleaned);
          if (bytes.isEmpty) return null;
          return _base32Encode(Uint8List.fromList(bytes));
        case _SecretEncoding.utf8:
          return _base32Encode(Uint8List.fromList(utf8.encode(cleaned)));
      }
    } catch (_) {
      return null;
    }
  }

  static const _b32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// RFC 4648 Base32 without padding (otp package accepts unpadded).
  static String _base32Encode(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    final buffer = StringBuffer();
    var bits = 0;
    var value = 0;
    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        buffer.write(_b32Alphabet[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) {
      buffer.write(_b32Alphabet[(value << (5 - bits)) & 31]);
    }
    return buffer.toString();
  }

  Uint8List? _hexDecode(String input) {
    var s = input;
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.length.isOdd) return null;
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final byte = int.tryParse(s.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }

  TotpConfig? _parseOtpAuthUri(String input) {
    if (!input.startsWith('otpauth://')) return null;
    final uri = Uri.tryParse(input);
    if (uri == null || uri.scheme != 'otpauth' || uri.host != 'totp') {
      return null;
    }

    try {
      final parameters = uri.queryParameters;
      final raw = parameters['secret'];
      final encoder = parameters['encoder'];
      if (raw == null || (encoder != null && encoder.isNotEmpty)) return null;
      final label = uri.pathSegments.join('/');
      final separator = label.indexOf(':');
      return _validatedConfig(
        secret: _normalizeSecret(raw, _SecretEncoding.base32),
        period: parameters['period'],
        digits: parameters['digits'],
        algorithm: parameters['algorithm'],
        issuer:
            parameters['issuer'] ??
            (separator < 0 ? null : label.substring(0, separator)),
        accountName: label.isEmpty ? null : label.substring(separator + 1),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  TotpConfig? _validatedConfig({
    required String? secret,
    String? period,
    String? digits,
    String? algorithm,
    String? issuer,
    String? accountName,
  }) {
    final step = period == null ? 30 : int.tryParse(period.trim());
    final length = digits == null ? 6 : int.tryParse(digits.trim());
    final hash = switch (algorithm?.trim().toUpperCase()) {
      null || 'SHA1' || 'HMAC-SHA-1' => 'SHA1',
      'SHA256' || 'HMAC-SHA-256' => 'SHA256',
      'SHA512' || 'HMAC-SHA-512' => 'SHA512',
      _ => null,
    };
    if (secret == null ||
        step == null ||
        step < 1 ||
        step > 86400 ||
        length == null ||
        length < 1 ||
        length > 10 ||
        hash == null) {
      return null;
    }
    return TotpConfig(
      secret: secret,
      period: step,
      digits: length,
      algorithm: hash,
      issuer: issuer,
      accountName: accountName,
    );
  }

  bool _looksLikeBase32(String s) {
    return s.isNotEmpty &&
        const {0, 2, 4, 5, 7}.contains(s.length % 8) &&
        RegExp(r'^[A-Z2-7]+$').hasMatch(s);
  }

  String _toKeePassAlgorithm(String algo) {
    switch (algo.toUpperCase()) {
      case 'SHA256':
      case 'HMAC-SHA-256':
        return 'HMAC-SHA-256';
      case 'SHA512':
      case 'HMAC-SHA-512':
        return 'HMAC-SHA-512';
      default:
        return 'HMAC-SHA-1';
    }
  }

  /// Maps KeePass / otpauth algorithm names to the standard otpauth form.
  static String toOtpAuthAlgorithm(String algo) {
    final upper = algo.toUpperCase();
    if (upper == 'SHA256' || upper == 'HMAC-SHA-256') return 'SHA256';
    if (upper == 'SHA512' || upper == 'HMAC-SHA-512') return 'SHA512';
    return 'SHA1';
  }
}

enum _SecretEncoding { base32, hex, base64, utf8 }
