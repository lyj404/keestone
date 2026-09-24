import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../../core/utils/fnv_hash.dart';
import '../../../core/utils/logger.dart';
import '../../database/data/atomic_file_store.dart';
import '../../settings/data/webdav_config.dart';

/// Normalizes a raw ETag header value for storage and replay in conditional
/// requests. Strips surrounding whitespace and the `W/` weak-validator prefix
/// (weak ETags replayed verbatim violate RFC 7232 and are rejected with 400
/// by some servers). Returns null for empty values.
String? normalizeETag(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (value.length >= 2 &&
      (value.codeUnitAt(0) | 0x20) == 0x77 /* w */ &&
      value.codeUnitAt(1) == 0x2f /* / */) {
    value = value.substring(2).trim();
  }
  return value.isEmpty ? null : value;
}

/// Builds the conditional-request headers for a database PUT so the upload
/// only lands when the remote revision still matches [expected].
///
/// - Strong (or normalized) ETag → `If-Match`.
/// - No known remote revision at all → `If-None-Match: *`, which only
///   succeeds when the file does not exist yet (protects an unseen remote).
/// - Validator-less server (no ETag) → `If-Unmodified-Since` from mTime.
/// - No validator of any kind on a previously seen revision → conflict:
///   the remote state cannot be verified, so uploading unconditionally is
///   not safe (it could overwrite a newer remote database).
Map<String, String> buildConditionalUploadHeaders(RemoteFileInfo? expected) {
  final eTag = normalizeETag(expected?.eTag);
  if (eTag != null) return {'if-match': eTag};
  if (expected == null) return {'if-none-match': '*'};
  final mTime = expected.mTime;
  if (mTime != null) {
    return {'if-unmodified-since': HttpDate.format(mTime.toUtc())};
  }
  throw SyncException(
    SyncErrorType.conflict,
    'Remote revision has no validator (no ETag/Last-Modified); '
    'refusing an unconditional upload',
  );
}

class RemoteFileInfo {
  final String? eTag;
  final DateTime? mTime;
  const RemoteFileInfo({this.eTag, this.mTime});
}

/// Normalizes a configured WebDAV path (collapses duplicate slashes, strips a
/// trailing slash) and percent-encodes characters that would break the request
/// URL. The webdav_client library joins the server URL and the path verbatim,
/// so spaces, '#' or '?' would produce an invalid request line or be parsed as
/// fragment/query separators. Existing percent-escapes are left untouched.
String encodeDavPath(String path) {
  var normalized = path.trim().replaceAll(RegExp(r'/+'), '/');
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.isEmpty) return '';
  final encoded = normalized
      .split('/')
      .map((segment) => segment.replaceAllMapped(
            RegExp(r"""[^A-Za-z0-9\-._~!$&'()*+,;=:@%]"""),
            (m) => Uri.encodeComponent(m[0]!),
          ))
      .join('/');
  // Root path stays a bare slash.
  return encoded.isEmpty ? '/' : encoded;
}

/// Classification of sync errors for user-friendly messaging.
enum SyncErrorType {
  network,
  auth,
  notFound,
  timeout,
  conflict,
  serverError,
  unknown,
}

class SyncException implements Exception {
  final SyncErrorType type;
  final String message;
  final Object? original;
  SyncException(this.type, this.message, [this.original]);

  @override
  String toString() => 'SyncException($type): $message';
}

/// Classifies a transport failure into a [SyncErrorType] using typed Dio
/// metadata and exception types. This is a pure top-level function so it can
/// be unit-tested without a live network connection. String matching is
/// intentionally avoided: it is fragile (a redirect body or unrelated message
/// containing "401" would misclassify) and unnecessary since dio and dart:io
/// expose structured status codes.
SyncErrorType classifySyncError(Object error) {
  if (error is SyncException) return error.type;
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) return SyncErrorType.auth;
    if (status == 404) return SyncErrorType.notFound;
    if (status == 409 || status == 412) return SyncErrorType.conflict;
    if (status != null && status >= 500) return SyncErrorType.serverError;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return SyncErrorType.timeout;
    }
    if (error.type == DioExceptionType.connectionError) {
      return SyncErrorType.network;
    }
  }
  if (error is SocketException) return SyncErrorType.network;
  if (error is TimeoutException) return SyncErrorType.timeout;
  // No typed metadata available — surface as unknown instead of guessing
  // from a human-readable message that may contain misleading substrings.
  return SyncErrorType.unknown;
}

class SyncService {
  webdav.Client? _cachedClient;
  WebDavConfig? _cachedConfig;
  static const _maxRetries = 3;
  static const _baseDelayMs = 1000;

  /// Classifies transport failures via the pure [classifySyncError] helper.
  SyncErrorType _classifyError(Object error) => classifySyncError(error);

  /// Whether an error is transient and worth retrying.
  bool _isRetryable(SyncErrorType type) {
    return type == SyncErrorType.network ||
        type == SyncErrorType.timeout ||
        type == SyncErrorType.serverError;
  }

  /// Wraps an async operation with exponential backoff retry for transient errors.
  Future<T> _withRetry<T>(String operation, Future<T> Function() action) async {
    Object? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        final type = _classifyError(e);
        if (!_isRetryable(type) || attempt == _maxRetries - 1) {
          log.e(
            '$operation failed (attempt ${attempt + 1}/$_maxRetries)',
            error: e,
          );
          if (type != SyncErrorType.unknown) {
            throw SyncException(type, e.toString(), e);
          }
          rethrow;
        }
        final delay = _baseDelayMs * pow(2, attempt).toInt();
        log.w(
          '$operation failed, retrying in ${delay}ms (attempt ${attempt + 1}/$_maxRetries): $e',
        );
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw lastError!;
  }

  /// Returns a cached WebDAV client, rebuilding it only when config changes.
  webdav.Client _buildClient(WebDavConfig config, {bool debug = false}) {
    if (!debug && _cachedClient != null && _cachedConfig == config) {
      return _cachedClient!;
    }
    final client = webdav.newClient(
      config.serverUrl,
      user: config.username,
      password: config.password,
      debug: debug,
    );
    client.setConnectTimeout(15000);
    client.setSendTimeout(15000);
    client.setReceiveTimeout(30000);
    if (!debug) {
      _cachedClient = client;
      _cachedConfig = config;
    }
    return client;
  }

  /// Clears cached WebDAV client and config to remove sensitive data from memory.
  void clearCache() {
    _cachedClient = null;
    _cachedConfig = null;
  }

  /// Tests WebDAV connection. Returns null on success, error key on failure.
  /// Error keys: 'auth_failed', 'path_not_accessible', 'connection_failed', 'network_failed'
  Future<String?> testConnection(WebDavConfig config) async {
    log.i('Testing WebDAV connection: ${config.serverUrl}');
    try {
      final client = _buildClient(config);
      final remotePath = config.remotePath.isEmpty ? '/' : encodeDavPath(config.remotePath);
      try {
        await client.readDir(remotePath);
      } catch (e) {
        switch (_classifyError(e)) {
          case SyncErrorType.auth:
            log.w('Auth failed');
            return 'auth_failed';
          case SyncErrorType.notFound:
            // Path missing but server reachable — connection itself is fine.
            return null;
          case SyncErrorType.conflict:
            return null;
          default:
            // Distinguish "server reachable, path bad" from "server unreachable".
            try {
              await client.ping();
              log.w('Path not accessible: $remotePath');
              return 'path_not_accessible:$remotePath';
            } catch (e2) {
              final msg = e2.toString();
              log.e('Connection failed', error: msg);
              return 'connection_failed:$msg';
            }
        }
      }
      log.i('Connection test passed');
      return null;
    } catch (e) {
      switch (_classifyError(e)) {
        case SyncErrorType.auth:
          log.w('Auth failed');
          return 'auth_failed';
        case SyncErrorType.network:
          log.e('Network failed');
          return 'network_failed';
        default:
          log.e('Connection failed', error: e);
          return 'connection_failed:$e';
      }
    }
  }

  Future<void> ensureRemoteDirectory(WebDavConfig config) async {
    final client = _buildClient(config);
    await client.mkdirAll(encodeDavPath(config.remotePath));
  }

  /// Returns null only when the remote file does not exist (404). Any other
  /// failure (auth, network, server) is thrown so callers cannot mistake an
  /// unreachable server for "no database on the cloud".
  Future<Uint8List?> downloadDatabase(WebDavConfig config) async {
    log.i('Downloading from: ${config.remoteFilePath}');
    final client = _buildClient(config);
    try {
      final bytes = await _withRetry(
        'Download',
        () => client.read(encodeDavPath(config.remoteFilePath)),
      );
      log.i('Downloaded ${bytes.length} bytes');
      return Uint8List.fromList(bytes);
    } catch (e) {
      final typed = _asSyncException(e);
      if (typed.type == SyncErrorType.notFound) return null;
      log.e('Download failed', error: typed);
      throw typed;
    }
  }

  /// Returns null only when the remote file does not exist (404). Any other
  /// failure (auth, network, server) is thrown so callers cannot mistake an
  /// unreachable server for "no database on the cloud" — that mistake guided
  /// users into overwriting a real remote database.
  Future<RemoteFileInfo?> getRemoteFileInfo(WebDavConfig config) async {
    final client = _buildClient(config);
    try {
      final file = await _withRetry(
        'GetFileInfo',
        () => client.readProps(encodeDavPath(config.remoteFilePath)),
      );
      return RemoteFileInfo(eTag: normalizeETag(file.eTag), mTime: file.mTime);
    } catch (e) {
      final typed = _asSyncException(e);
      if (typed.type == SyncErrorType.notFound) return null;
      log.e('GetFileInfo failed', error: typed);
      throw typed;
    }
  }

  /// Downloads bytes and revision metadata from the same HTTP GET response,
  /// avoiding a read/readProps race where the reported ETag could belong to a
  /// newer version than the downloaded bytes.
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(
    WebDavConfig config,
  ) async {
    log.i('Downloading database with revision metadata');
    final client = _buildClient(config);
    try {
      final response = await _withRetry(
        'Download',
        () => client.c.req<List<int>>(
          client,
          'GET',
          encodeDavPath(config.remoteFilePath),
          optionsHandler: (options) =>
              options.responseType = ResponseType.bytes,
        ),
      );
      final status = response.statusCode;
      if (status != 200) throw _httpException(status, response.statusMessage);
      final data = response.data;
      if (data == null) {
        throw SyncException(SyncErrorType.serverError, 'Empty WebDAV response');
      }
      final info = RemoteFileInfo(
        eTag: normalizeETag(response.headers.value('etag')),
        mTime: _parseHttpDate(response.headers.value('last-modified')),
      );
      log.i('Downloaded ${data.length} bytes with a revision token');
      return (bytes: Uint8List.fromList(data), info: info);
    } catch (error) {
      final typed = _asSyncException(error);
      log.e('Download with info failed', error: typed);
      if (typed.type == SyncErrorType.notFound) return null;
      throw typed;
    }
  }

  /// Atomically uploads only if the remote revision still matches
  /// [expected]. New files use If-None-Match so an unexpectedly created file
  /// cannot be overwritten. Conditional PUT is deliberately never retried:
  /// after an ambiguous network failure the caller must fetch remote state.
  Future<RemoteFileInfo> uploadDatabase(
    WebDavConfig config,
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
    log.i('Uploading ${bytes.length} bytes with conflict protection');
    final client = _buildClient(config);
    // Computed before the request so a missing validator fails fast with a
    // conflict instead of silently uploading unconditionally.
    final conditionalHeaders = force
        ? const <String, String>{}
        : buildConditionalUploadHeaders(expected);
    try {
      final response = await client.c.req<void>(
        client,
        'PUT',
        encodeDavPath(config.remoteFilePath),
        data: Stream<List<int>>.value(bytes),
        optionsHandler: (options) {
          options.headers?['content-length'] = bytes.length;
          options.headers?.addAll(conditionalHeaders);
        },
      );
      final status = response.statusCode;
      if (status != 200 && status != 201 && status != 204) {
        throw _httpException(status, response.statusMessage);
      }
      log.i('Upload complete');
      final responseETag = normalizeETag(response.headers.value('etag'));
      final responseMTime = _parseHttpDate(
        response.headers.value('last-modified'),
      );
      if (responseETag != null || responseMTime != null) {
        return RemoteFileInfo(eTag: responseETag, mTime: responseMTime);
      }
      return await getRemoteFileInfo(config) ?? const RemoteFileInfo();
    } catch (error) {
      final typed = _asSyncException(error);
      log.e('Upload failed', error: typed);
      throw typed;
    }
  }

  SyncException _httpException(int? status, String? message) {
    final type = switch (status) {
      401 || 403 => SyncErrorType.auth,
      404 => SyncErrorType.notFound,
      409 || 412 => SyncErrorType.conflict,
      int value when value >= 500 => SyncErrorType.serverError,
      _ => SyncErrorType.unknown,
    };
    return SyncException(
      type,
      'WebDAV HTTP ${status ?? 'unknown'}: ${message ?? ''}',
    );
  }

  SyncException _asSyncException(Object error) => error is SyncException
      ? error
      : SyncException(_classifyError(error), 'WebDAV operation failed', error);

  DateTime? _parseHttpDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Returns true only when the remote file exists; false only when the
  /// server answers 404. Any other failure (auth, network, server) is thrown
  /// so callers cannot treat an unreachable server as "no remote database".
  Future<bool> remoteFileExists(WebDavConfig config) async {
    final client = _buildClient(config);
    try {
      await client.readProps(encodeDavPath(config.remoteFilePath));
      return true;
    } catch (e) {
      final typed = _asSyncException(e);
      if (typed.type == SyncErrorType.notFound) return false;
      log.e('remoteFileExists failed', error: typed);
      throw typed;
    }
  }

  /// Downloads remote database and writes it to the local cloud cache.
  /// Returns path + revision metadata from the same GET response so callers
  /// never persist a stale ETag against newer bytes.
  Future<({String path, RemoteFileInfo info})> downloadToLocal(
    WebDavConfig config,
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

  String _cacheFileNameFor(WebDavConfig config) {
    final extension = _normalizedExtension(config.remoteFilename);
    final identity =
        '${config.serverUrl.trim()}|${config.remoteFilePath.trim()}';
    final hash = _stableHash(identity);
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

  String _stableHash(String input) => FnvHash.hashString(input);
}
