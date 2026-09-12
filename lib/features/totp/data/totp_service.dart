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
  static const _kSecret = 'TimeOtp-Secret';
  static const _kPeriod = 'TimeOtp-Period';
  static const _kSize = 'TimeOtp-Size';
  static const _kAlgorithm = 'TimeOtp-Algorithm';

  /// Cheap check for whether [entry] carries a TOTP secret, without fully
  /// parsing the rest of the config. Used to filter lists before the more
  /// expensive [loadFromEntry] is deferred to each tile.
  bool hasTotp(KdbxEntry entry) {
    final cd = entry.customData;
    if (cd == null) return false;
    final secret = cd.map[_kSecret]?.value;
    return secret != null && secret.isNotEmpty;
  }

  TotpConfig? loadFromEntry(KdbxEntry entry) {
    final cd = entry.customData;
    if (cd == null) return null;

    final secret = cd.map[_kSecret]?.value;
    if (secret == null || secret.isEmpty) return null;

    final period = int.tryParse(cd.map[_kPeriod]?.value ?? '') ?? 30;
    final digits = int.tryParse(cd.map[_kSize]?.value ?? '') ?? 6;
    final algorithm = cd.map[_kAlgorithm]?.value ?? 'HMAC-SHA-1';

    return TotpConfig(
      secret: secret,
      period: period,
      digits: digits,
      algorithm: algorithm,
    );
  }

  void saveToEntry(KdbxEntry entry, TotpConfig config) {
    entry.customData ??= KdbxCustomData();
    final cd = entry.customData!;

    cd.map[_kSecret] = KdbxCustomItem(value: config.secret);
    cd.map[_kPeriod] = KdbxCustomItem(value: config.period.toString());
    cd.map[_kSize] = KdbxCustomItem(value: config.digits.toString());
    cd.map[_kAlgorithm] = KdbxCustomItem(value: _toKeePassAlgorithm(config.algorithm));
  }

  void removeFromEntry(KdbxEntry entry) {
    final cd = entry.customData;
    if (cd == null) return;
    cd.map.remove(_kSecret);
    cd.map.remove(_kPeriod);
    cd.map.remove(_kSize);
    cd.map.remove(_kAlgorithm);
  }

  String generateCode(TotpConfig config) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return OTP.generateTOTPCodeString(
      config.secret,
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
