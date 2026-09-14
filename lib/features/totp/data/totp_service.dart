import 'dart:convert';
import 'dart:typed_data';

import 'package:kpasslib/kpasslib.dart';
import 'package:otp/otp.dart';

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

  /// Cheap check for whether [entry] carries a TOTP secret, without fully
  /// parsing the rest of the config. Used to filter lists before the more
  /// expensive [loadFromEntry] is deferred to each tile.
  ///
  /// Covers KeePass standard string fields, this app's legacy customData
  /// storage, and an otpauth:// URI in a `TOTP` custom field.
  bool hasTotp(KdbxEntry entry) {
    if (_fieldSecretSource(entry) != null) return true;
    final cd = entry.customData;
    if (cd != null) {
      final secret = cd.map[_kSecret]?.value;
      if (secret != null && secret.isNotEmpty) return true;
    }
    return _otpAuthFromTotpField(entry) != null;
  }

  TotpConfig? loadFromEntry(KdbxEntry entry) {
    final period = _readInt(entry, _kPeriod) ?? 30;
    final digits =
        _readInt(entry, _kLength) ?? _readInt(entry, _kSize) ?? 6;
    final algorithm =
        _readString(entry, _kAlgorithm) ?? 'HMAC-SHA-1';

    final fromFields = _fieldSecretSource(entry);
    if (fromFields != null) {
      final secret = _normalizeSecret(fromFields.value, fromFields.encoding);
      if (secret != null) {
        return TotpConfig(
          secret: secret,
          period: period,
          digits: digits,
          algorithm: algorithm,
        );
      }
    }

    final cd = entry.customData;
    final legacy = cd?.map[_kSecret]?.value;
    if (legacy != null && legacy.isNotEmpty) {
      // Historic app storage: value is treated as Base32.
      final secret = _normalizeSecret(legacy, _SecretEncoding.base32);
      if (secret != null) {
        return TotpConfig(
          secret: secret,
          period: period,
          digits: digits,
          algorithm: algorithm,
        );
      }
    }

    return _otpAuthFromTotpField(entry);
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

    final config = loadFromEntry(entry);
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

  void removeFromEntry(KdbxEntry entry) {
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

  String generateCode(TotpConfig config) {
    final now = DateTime.now().millisecondsSinceEpoch;
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
  int remainingSeconds(TotpConfig config) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return config.period - (nowSec % config.period);
  }

  TotpConfig? parseUri(String input) {
    final uri = input.trim();
    if (uri.startsWith('otpauth://')) {
      return _parseOtpAuthUri(uri);
    }
    if (_looksLikeBase32(uri)) {
      return TotpConfig(secret: uri.replaceAll(' ', ''));
    }
    return null;
  }

  TotpConfig? _otpAuthFromTotpField(KdbxEntry entry) {
    final raw = entry.fields[_kTotpField]?.text;
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('otpauth://')) return null;
    return parseUri(raw);
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

  int? _readInt(KdbxEntry entry, String key) {
    final s = _readString(entry, key);
    if (s == null) return null;
    final parsed = int.tryParse(s);
    if (parsed != null && parsed > 0) return parsed;
    final cd = entry.customData?.map[key]?.value;
    if (cd == null) return null;
    return int.tryParse(cd);
  }

  /// Converts any supported secret encoding into the Base32 form required
  /// by the `otp` package. Returns null when the payload cannot be decoded.
  String? _normalizeSecret(String secret, _SecretEncoding encoding) {
    try {
      final cleaned = secret.replaceAll(' ', '').replaceAll('\n', '');
      switch (encoding) {
        case _SecretEncoding.base32:
          final stripped = cleaned.replaceAll('=', '').toUpperCase();
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

  TotpConfig? _parseOtpAuthUri(String uriStr) {
    final uri = Uri.tryParse(uriStr);
    if (uri == null || uri.scheme != 'otpauth' || uri.host != 'totp') return null;

    String? secret;
    int period = 30;
    int digits = 6;
    String algorithm = 'SHA1';
    String? issuer;
    String? accountName;

    secret = uri.queryParameters['secret'];
    if (secret == null || secret.isEmpty) return null;
    secret = secret.replaceAll(' ', '');
    if (!_looksLikeBase32(secret)) return null;

    final p = uri.queryParameters['period'];
    if (p != null) period = int.tryParse(p) ?? 30;

    final d = uri.queryParameters['digits'];
    if (d != null) digits = int.tryParse(d) ?? 6;

    final a = uri.queryParameters['algorithm'];
    if (a != null) algorithm = a;

    issuer = uri.queryParameters['issuer'];

    final path = uri.path;
    if (path.isNotEmpty && path.startsWith('/')) {
      final label = Uri.decodeComponent(path.substring(1));
      final parts = label.split(':');
      if (parts.length >= 2) {
        issuer ??= parts[0];
        accountName = parts.sublist(1).join(':');
      } else {
        accountName = label;
      }
    }

    return TotpConfig(
      secret: secret,
      period: period,
      digits: digits,
      algorithm: algorithm,
      issuer: issuer,
      accountName: accountName,
    );
  }

  bool _looksLikeBase32(String s) {
    final cleaned = s.replaceAll(' ', '').replaceAll('-', '');
    if (cleaned.length < 16) return false;
    return RegExp(r'^[A-Za-z2-7]+=*$').hasMatch(cleaned);
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
