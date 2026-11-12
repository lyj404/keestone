import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/fnv_hash.dart';
import '../../../core/utils/logger.dart';
import '../../database/data/atomic_file_store.dart';
import 's3_config.dart';
import 'sync_service.dart'
    show
        RemoteFileInfo,
        SyncErrorType,
        SyncException,
        classifySyncError,
        normalizeETag;

/// Reusable error classification lives in sync_service.dart.
export 'sync_service.dart'
    show RemoteFileInfo, SyncErrorType, SyncException, classifySyncError;

/// The empty-payload SHA-256, used as the signed payload hash for HEAD/GET
/// requests per the SigV4 spec.
const String kEmptySha256Hex =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// Hex-encodes bytes with lowercase letters (SigV4 requires lowercase hex).
String hexEncodeLower(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Future<String> _sha256Hex(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return hexEncodeLower(digest.bytes);
}

/// Builds the canonical query string from already-decoded pairs, sorted by
/// key then value per the SigV4 spec. An empty list yields ''.
String canonicalQueryString(List<MapEntry<String, String>> params) {
  final encoded = params
      .map(
        (e) => (
          key: awsUriEncode(e.key),
          value: awsUriEncode(e.value),
        ),
      )
      .toList()
    ..sort((a, b) {
      final byKey = a.key.compareTo(b.key);
      return byKey != 0 ? byKey : a.value.compareTo(b.value);
    });
  return encoded.map((e) => '${e.key}=${e.value}').join('&');
}

/// The signed request material produced by [signSigV4].
class SigV4Result {
  /// Value for the `Authorization` header.
  final String authorization;

  /// ISO8601 basic-format timestamp, e.g. `20130524T000000Z`.
  final String amzDate;

  /// YYYYMMDD scope date shared with the credential block.
  final String dateStamp;

  /// Signed payload hash (the `x-amz-content-sha256` value).
  final String payloadHash;

  const SigV4Result({
    required this.authorization,
    required this.amzDate,
    required this.dateStamp,
    required this.payloadHash,
  });
}

/// Computes the AWS Signature V4 for one request. Pure apart from hashing,
/// so tests can verify it against AWS's published vectors.
///
/// [hostHeader] is the Host header value (authority, no scheme). [extraHeaders]
/// carries additional headers that must be signed (e.g.
/// `x-amz-security-token`); `x-amz-date` and `x-amz-content-sha256` are added
/// automatically. Query parameters come pre-decoded via [queryParams].
Future<SigV4Result> signSigV4({
  required String method,
  required String canonicalUri,
  required String hostHeader,
  required String payloadHash,
  required String accessKeyId,
  required String secretAccessKey,
  required String region,
  String service = 's3',
  Map<String, String> extraHeaders = const {},
  List<MapEntry<String, String>> queryParams = const [],
  required DateTime now,
}) async {
  final dateStamp = _basicDate(now);
  final amzDate = '$dateStamp'
      'T${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}Z';

  final signedHeadersMap = <String, String>{
    'host': hostHeader,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
    ..._lowercased(extraHeaders),
  };
  final names = signedHeadersMap.keys.toList()..sort();
  final signedHeaders = names.join(';');
  final canonicalHeaders = names
      .map((name) => '$name:${signedHeadersMap[name]!.trim()}\n')
      .join();
  final canonicalQuery = canonicalQueryString(queryParams);

  // Canonical request: METHOD \n canonicalUri \n query \n headers \n
  // signedHeaders \n payloadHash.
  final canonicalRequest = [
    method,
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');

  final scope = '$dateStamp/$region/$service/aws4_request';
  final stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    scope,
    await _sha256Hex(canonicalRequest.codeUnits),
  ].join('\n');

  // Derive the signing key: kSecret -> kDate -> kRegion -> kService ->
  // kSigning, all binary HMACs.
  var key = await _hmacSha256(
    'AWS4$secretAccessKey'.codeUnits,
    dateStamp.codeUnits,
  );
  key = await _hmacSha256(key, region.codeUnits);
  key = await _hmacSha256(key, service.codeUnits);
  key = await _hmacSha256(key, 'aws4_request'.codeUnits);
  final signature = hexEncodeLower(
    await _hmacSha256(key, stringToSign.codeUnits),
  );

  final authorization =
      'AWS4-HMAC-SHA256 Credential=$accessKeyId/$scope,'
      'SignedHeaders=$signedHeaders,Signature=$signature';
  return SigV4Result(
    authorization: authorization,
    amzDate: amzDate,
    dateStamp: dateStamp,
    payloadHash: payloadHash,
  );
}

Map<String, String> _lowercased(Map<String, String> headers) => {
  for (final entry in headers.entries)
    entry.key.toLowerCase(): entry.value,
};

String _basicDate(DateTime utc) =>
    '${utc.year.toString().padLeft(4, '0')}'
    '${utc.month.toString().padLeft(2, '0')}'
    '${utc.day.toString().padLeft(2, '0')}';

Future<List<int>> _hmacSha256(List<int> key, List<int> data) async {
  final mac = await Hmac.sha256().calculateMac(
    data,
    secretKey: SecretKey(key),
  );
  return mac.bytes;
}

/// S3-compatible sync backend built on the S3 REST API with Signature V4
/// signing (works with AWS S3 and self-hosted compatible services such as
/// MinIO, R2, B2, OSS, COS).
///
/// The database is one object in a bucket. The revision token is the object
/// ETag surfaced through [RemoteFileInfo.eTag] so the DatabaseNotifier
/// conflict machinery (conditional upload, pendingUpload, diff dialog) works
/// unchanged. Conditional writes via If-Match are deliberately not sent:
/// support across S3-compatible stores is inconsistent, and a silently
/// ignored conditional header is worse than the Git-style check-then-put
/// this backend uses instead.
class S3SyncService {
  static const _maxRetries = 3;
  static const _baseDelayMs = 1000;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (_) => true,
    ),
  );

  void dispose() => _dio.close();

  /// Returns the database object's revision token, or null when there is no
  /// object yet (first sync). Any other failure throws so callers cannot
  /// mistake an unreachable server for "no database on the cloud".
  Future<RemoteFileInfo?> getRemoteFileInfo(S3SyncConfig config) async {
    final response = await _request(
      config,
      'HEAD',
      config.objectKey,
      payloadHash: kEmptySha256Hex,
      operation: 'HeadObject',
    );
    final status = response.statusCode;
    if (status == 404) return null;
    _assertStatus(status, 'HeadObject');
    return RemoteFileInfo(
      eTag: normalizeETag(response.headers.value('etag')),
      mTime: _parseHttpDate(response.headers.value('last-modified')),
    );
  }

  /// Downloads the object bytes and its revision token in one round trip,
  /// mirroring the WebDAV downloadWithInfo race-avoidance.
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(
    S3SyncConfig config,
  ) async {
    final response = await _request(
      config,
      'GET',
      config.objectKey,
      payloadHash: kEmptySha256Hex,
      operation: 'GetObject',
      responseType: ResponseType.bytes,
    );
    if (response.statusCode == 404) return null;
    _assertStatus(response.statusCode, 'GetObject');
    final data = response.data;
    if (data is! List<int>) {
      throw SyncException(
        SyncErrorType.serverError,
        'Unexpected S3 response payload',
      );
    }
    final info = RemoteFileInfo(
      eTag: normalizeETag(response.headers.value('etag')),
      mTime: _parseHttpDate(response.headers.value('last-modified')),
    );
    return (bytes: Uint8List.fromList(data), info: info);
  }

  /// Uploads the database as one object. With [expected] the local revision
  /// token is compared against the remote's before writing; a mismatch maps
  /// to [SyncErrorType.conflict] so the caller's diff dialog opens, matching
  /// the WebDAV 412 flow. Never retried after the check once writing starts:
  /// an ambiguous network failure means the caller must fetch remote state.
  Future<RemoteFileInfo> uploadDatabase(
    S3SyncConfig config,
    Uint8List bytes, {
    RemoteFileInfo? expected,
    bool force = false,
  }) async {
    // A zero-length PUT would destroy the remote database. This can only
    // happen if the caller serialized a closed database, so refuse loudly
    // instead of letting an unconditional overwrite through.
    if (bytes.isEmpty) {
      throw SyncException(
        SyncErrorType.unknown,
        'Refusing to upload an empty database file',
      );
    }
    if (!force && expected?.eTag != null) {
      final remote = await getRemoteFileInfo(config);
      if (remote != null && remote.eTag != expected!.eTag) {
        throw SyncException(
          SyncErrorType.conflict,
          'Remote database changed before upload',
        );
      }
    }

    final payloadHash = await _sha256Hex(bytes);
    final response = await _request(
      config,
      'PUT',
      config.objectKey,
      payloadHash: payloadHash,
      body: bytes,
      operation: 'PutObject',
    );
    _assertStatus(response.statusCode, 'PutObject');
    final eTag = normalizeETag(response.headers.value('etag'));
    if (eTag != null) {
      return RemoteFileInfo(eTag: eTag);
    }
    // Some stores omit ETag on the PUT response; a follow-up HEAD recovers
    // the revision token so the caller can still do conditional uploads.
    return await getRemoteFileInfo(config) ?? const RemoteFileInfo();
  }

  /// Returns true only when the object exists; false only when the server
  /// answers 404. Any other failure is thrown so callers cannot treat an
  /// unreachable server as "no remote database".
  Future<bool> remoteFileExists(S3SyncConfig config) async {
    final response = await _request(
      config,
      'HEAD',
      config.objectKey,
      payloadHash: kEmptySha256Hex,
      operation: 'HeadObject',
    );
    if (response.statusCode == 404) return false;
    _assertStatus(response.statusCode, 'HeadObject');
    return true;
  }

  /// Tests the connection by issuing a HEAD request against the bucket.
  /// Returns null on success, error key on failure. Error keys:
  /// 'auth_failed', 'bucket_not_found:`<bucket>`',
  /// 'connection_failed:`<msg>`', 'network_failed'.
  Future<String?> testConnection(S3SyncConfig config) async {
    log.i('[S3Sync] Testing connection: ${config.endpoint}');
    try {
      final response = await _request(
        config,
        'HEAD',
        null,
        payloadHash: kEmptySha256Hex,
        operation: 'HeadBucket',
      );
      switch (_typeForStatus(response.statusCode)) {
        case SyncErrorType.notFound:
          return 'bucket_not_found:${config.bucket}';
        case SyncErrorType.auth:
          return 'auth_failed';
        case SyncErrorType.serverError:
          return 'connection_failed:HTTP ${response.statusCode}';
        default:
          return null;
      }
    } catch (e) {
      final type = classifySyncError(e);
      if (type == SyncErrorType.network || type == SyncErrorType.timeout) {
        log.e('[S3Sync] Network failed', error: e);
        return 'network_failed';
      }
      log.e('[S3Sync] Connection failed', error: e);
      return 'connection_failed:$e';
    }
  }

  /// Downloads the remote database and writes it to the local cloud cache,
  /// mirroring SyncService.downloadToLocal so the rest of the open-from-cloud
  /// flow (recent-file records, unlock screen, pendingUpload) works unchanged.
  Future<({String path, RemoteFileInfo info})> downloadToLocal(
    S3SyncConfig config,
  ) async {
    final result = await downloadWithInfo(config);
    if (result == null) throw Exception('remote_database_not_exist');
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/keestone_cloud_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final file = File('${cacheDir.path}/${_cacheFileNameFor(config)}');
    // The cache file is also the save target while the database is open from
    // the cloud, so the replacement must be atomic: a bare writeAsBytes
    // interrupted mid-write would corrupt the only local copy.
    await const AtomicFileStore().commit(file.path, result.bytes);
    return (path: file.path, info: result.info);
  }

  String _cacheFileNameFor(S3SyncConfig config) {
    final extension = _normalizedExtension(config.remoteFilename);
    final identity =
        '${config.endpoint.trim()}|${config.bucket.trim()}|'
        '${config.objectKey.trim()}';
    final hash = FnvHash.hashString(identity);
    final safeName = _sanitizeFileStem(config.remoteFilename);
    return '${safeName}_$hash$extension';
  }

  String _sanitizeFileStem(String filename) {
    final normalized = filename.trim();
    final dotIndex = normalized.lastIndexOf('.');
    final stem = dotIndex > 0 ? normalized.substring(0, dotIndex) : normalized;
    final cleaned = stem.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'keestone_sync' : cleaned;
  }

  String _normalizedExtension(String filename) {
    final normalized = filename.trim();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == normalized.length - 1) {
      return '.kdbx';
    }
    final extension = normalized.substring(dotIndex);
    final cleaned = extension.replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
    return cleaned.isEmpty ? '.kdbx' : cleaned;
  }

  /// Signed request against [key]; null means a bucket-level request.
  /// Retries transient failures with backoff; each attempt is signed fresh
  /// so the x-amz-date header matches the replayed request.
  Future<Response<dynamic>> _request(
    S3SyncConfig config,
    String method,
    String? key, {
    required String payloadHash,
    required String operation,
    Uint8List? body,
    ResponseType? responseType,
  }) {
    return _withRetry(operation, () async {
      // One string serves as both the wire path and the SigV4 canonical URI,
      // so the signed path is byte-identical to the path the server sees.
      // The URL is assembled directly — Uri.parse would re-normalize escapes.
      final wirePath = config.requestPath(key);
      final hostHeader = config.requestHost();
      final extraHeaders = <String, String>{
        if (config.sessionToken.trim().isNotEmpty)
          'x-amz-security-token': config.sessionToken.trim(),
      };
      final signed = await signSigV4(
        method: method,
        canonicalUri: wirePath,
        hostHeader: hostHeader,
        payloadHash: payloadHash,
        accessKeyId: config.accessKeyId.trim(),
        secretAccessKey: config.secretAccessKey.trim(),
        region: _region(config),
        extraHeaders: extraHeaders,
        now: DateTime.now().toUtc(),
      );
      return _dio.request<dynamic>(
        config.requestUrl(wirePath),
        data: body,
        options: Options(
          method: method,
          responseType: responseType,
          headers: {
            'Authorization': signed.authorization,
            'x-amz-content-sha256': signed.payloadHash,
            'x-amz-date': signed.amzDate,
            ...extraHeaders,
          },
        ),
      );
    });
  }

  String _region(S3SyncConfig config) {
    final region = config.region.trim();
    return region.isEmpty ? 'us-east-1' : region;
  }

  void _assertStatus(int? status, String operation) {
    if (status != null && status >= 200 && status < 300) return;
    throw SyncException(
      _typeForStatus(status),
      '$operation HTTP ${status ?? 'unknown'}',
    );
  }

  SyncErrorType _typeForStatus(int? status) {
    if (status == 401 || status == 403) return SyncErrorType.auth;
    if (status == 404) return SyncErrorType.notFound;
    if (status == 409 || status == 412) return SyncErrorType.conflict;
    if (status != null && status >= 500) return SyncErrorType.serverError;
    return SyncErrorType.unknown;
  }

  DateTime? _parseHttpDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<T> _withRetry<T>(String operation, Future<T> Function() action) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        final type = classifySyncError(e);
        final retryable =
            type == SyncErrorType.network ||
            type == SyncErrorType.timeout ||
            type == SyncErrorType.serverError;
        if (!retryable || attempt == _maxRetries - 1) {
          log.e(
            '[S3Sync] $operation failed (attempt ${attempt + 1}/$_maxRetries)',
            error: e,
          );
          if (e is SyncException) rethrow;
          throw SyncException(type, e.toString(), e);
        }
        final delay = _baseDelayMs * pow(2, attempt).toInt();
        log.w('[S3Sync] $operation failed, retrying in ${delay}ms: $e');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw lastError!;
  }
}
