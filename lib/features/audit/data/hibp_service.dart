import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

/// Result of checking one password against the HIBP Pwned Passwords API.
class HibpCheckResult {
  /// Number of times the exact password appears in known breaches.
  /// 0 means not found in any known breach.
  final int occurrenceCount;

  /// True when the check could not complete (network error, rate limit…).
  final bool errored;

  const HibpCheckResult({required this.occurrenceCount, this.errored = false});

  bool get pwned => !errored && occurrenceCount > 0;
}

/// Have I Been Pwned "Pwned Passwords" client using k-anonymity: only the
/// first 5 hex characters of the SHA-1 hash of a password ever leave the
/// device. The full hash and the plaintext never do.
///
/// Intentionally manual: callers must invoke [checkPassword] from an explicit
/// user action so the app keeps its offline-by-default behavior.
class HibpService {
  static const _apiPrefix = 'https://api.pwnedpasswords.com/range/';
  static const _rangePrefixLength = 5;
  static const _timeout = Duration(seconds: 15);

  final Dio _dio;

  HibpService({Dio? dio})
    : _dio =
          dio ??
          Dio(BaseOptions(
            connectTimeout: _timeout,
            receiveTimeout: _timeout,
            responseType: ResponseType.plain,
          ));

  /// Checks a single password. Returns a result with [HibpCheckResult.errored]
  /// set on network/server failure instead of throwing.
  Future<HibpCheckResult> checkPassword(String password) async {
    try {
      final count = await _queryCount(password);
      return HibpCheckResult(occurrenceCount: count);
    } catch (e) {
      return const HibpCheckResult(occurrenceCount: 0, errored: true);
    }
  }

  Future<int> _queryCount(String password) async {
    final sha1 = await Sha1().hash(utf8.encode(password));
    final hex = sha1.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final prefix = hex.substring(0, _rangePrefixLength).toUpperCase();
    final suffix = hex.substring(_rangePrefixLength).toUpperCase();

    final response = await _dio.get<String>('$_apiPrefix$prefix');
    final body = response.data ?? '';
    for (final line in body.split('\n')) {
      final sep = line.indexOf(':');
      if (sep <= 0) continue;
      if (line.substring(0, sep).trim() == suffix) {
        return int.tryParse(line.substring(sep + 1).trim()) ?? 0;
      }
    }
    return 0;
  }
}
