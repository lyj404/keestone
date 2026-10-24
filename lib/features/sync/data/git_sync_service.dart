import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/fnv_hash.dart';
import '../../../core/utils/logger.dart';
import '../../database/data/atomic_file_store.dart';
import 'git_config.dart';
import 'sync_service.dart'
    show RemoteFileInfo, SyncErrorType, SyncException, classifySyncError;

/// Reusable error classification lives in sync_service.dart.
export 'sync_service.dart'
    show RemoteFileInfo, SyncErrorType, SyncException, classifySyncError;

/// Named record shape returned by [GitSyncConfig.parsedRepo]. Dart treats
/// positional and named records as distinct types, so passing this around
/// needs an explicit alias.
typedef _RepoRef = ({String apiBase, String provider});

/// Git-hosting sync backend built on the provider's snippet API — the same
/// approach Termora uses (GitHub Gist / Gitee Gist / GitLab Snippet).
///
/// The database is stored as one file inside a secret gist/snippet. The
/// first push creates it, later pushes PATCH/PUT it, so there are no
/// branches to manage and no empty-repository edge case. The revision token
/// is a SHA-1 of the stored file content, surfaced through
/// [RemoteFileInfo.eTag] so the DatabaseNotifier conflict machinery
/// (conditional upload, pendingUpload, diff dialog) works unchanged.
class GitSyncService {
  static const _maxRetries = 3;
  static const _baseDelayMs = 1000;

  /// Called once after the first push creates the gist/snippet, with the
  /// config updated to carry the new [GitSyncConfig.gistId]. Persisting it
  /// is what turns later syncs into updates instead of new snippets.
  Future<void> Function(GitSyncConfig config)? onGistIdCreated;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (_) => true,
    ),
  );

  void dispose() => _dio.close();

  /// Returns the database file's content hash, or null when there is no
  /// snippet yet (first sync) or no such file inside it.
  Future<RemoteFileInfo?> getRemoteFileInfo(GitSyncConfig config) async {
    final content = await _readSnippetFile(config);
    if (content == null) return null;
    return RemoteFileInfo(eTag: await _shaOf(content), mTime: null);
  }

  /// Downloads the file bytes and its revision token in one round trip
  /// (two for GitLab, whose snippet endpoint does not inline file content).
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(
    GitSyncConfig config,
  ) async {
    final content = await _readSnippetFile(config);
    if (content == null) return null;
    final bytes = base64Decode(content);
    return (bytes: bytes, info: RemoteFileInfo(eTag: await _shaOf(content)));
  }

  /// Uploads the database as the snippet file. With [expected] the local
  /// revision token is compared against the remote's before writing; a
  /// mismatch maps to [SyncErrorType.conflict] so the caller's diff dialog
  /// opens, matching the WebDAV 412 flow.
  Future<RemoteFileInfo> uploadDatabase(
    GitSyncConfig config,
    Uint8List bytes, {
    RemoteFileInfo? expected,
    bool force = false,
  }) async {
    if (bytes.isEmpty) {
      throw SyncException(
        SyncErrorType.unknown,
        'Refusing to upload an empty database file',
      );
    }
    final parsed = config.parsedRepo;
    if (parsed == null) {
      throw SyncException(SyncErrorType.unknown, 'Invalid repository URL');
    }
    // KDBX bytes are binary; the snippet file stores them base64-encoded so
    // the JSON-based gist/snippet APIs round-trip them losslessly. The
    // revision token hashes the base64 text, consistently on both sides.
    final content = base64Encode(bytes);
    final newSha = await _shaOf(content);
    final expectedSha = normalizeSha(expected?.eTag);

    if (!force && expectedSha != null) {
      final remote = await getRemoteFileInfo(config);
      if (remote != null && remote.eTag != expectedSha) {
        throw SyncException(
          SyncErrorType.conflict,
          'Remote database changed before upload',
        );
      }
    }

    final gistId = config.gistId.trim();
    if (gistId.isEmpty) {
      // Blank gist id: either a genuine first sync or a lost id (e.g. an
      // older build overwrote the profile). Reuse an existing KeeStone
      // snippet when one is found so uploads never stack duplicates; only
      // create when none exists.
      final recoveredId = await _findExistingSnippetId(config, parsed);
      final id = recoveredId ?? await _createSnippet(config, parsed, content);
      final callback = onGistIdCreated;
      if (callback != null) {
        await callback(config.copyWith(gistId: id));
      }
      return RemoteFileInfo(eTag: newSha);
    }
    // Stale id (snippet deleted on the provider): recover or create, then
    // persist the new id so future syncs do not keep failing.
    final fetched = await _fetchSnippetWithRecovery(config, parsed, gistId);
    if (fetched == null) {
      final id = await _createSnippet(config, parsed, content);
      final callback = onGistIdCreated;
      if (callback != null) {
        await callback(config.copyWith(gistId: id));
      }
      return RemoteFileInfo(eTag: newSha);
    }
    await _updateSnippet(config, parsed, fetched.id, content);
    if (fetched.id != gistId) {
      final callback = onGistIdCreated;
      if (callback != null) {
        await callback(config.copyWith(gistId: fetched.id));
      }
    }
    return RemoteFileInfo(eTag: newSha);
  }

  /// Downloads the remote database and writes it to the local cloud cache,
  /// mirroring SyncService.downloadToLocal so the rest of the open-from-cloud
  /// flow (recent-file records, unlock screen, pendingUpload) works unchanged.
  Future<({String path, RemoteFileInfo info})> downloadToLocal(
    GitSyncConfig config,
  ) async {
    final result = await downloadWithInfo(config);
    if (result == null) throw Exception('remote_database_not_exist');
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/keestone_cloud_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final file = File('${cacheDir.path}/${_cacheFileNameFor(config)}');
    await const AtomicFileStore().commit(file.path, result.bytes);
    return (path: file.path, info: result.info);
  }

  String _cacheFileNameFor(GitSyncConfig config) {
    final extension = _normalizedExtension(config.remoteFilename);
    final identity =
        '${config.parsedRepo?.apiBase ?? config.repoUrl.trim()}|${config.gistId.trim()}|${config.filePath.trim()}';
    final hash = FnvHash.hashString(identity);
    return '${_sanitizeFileStem(config.remoteFilename)}_$hash$extension';
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

  /// Reads the database file from the configured gist/snippet. Returns null
  /// only when there is no snippet or no such file; any other failure throws
  /// so callers never mistake an unreachable server for "no remote database".
  Future<String?> _readSnippetFile(GitSyncConfig config) async {
    final parsed = config.parsedRepo;
    if (parsed == null) {
      log.w(
        '[GitSync] Read failed: invalid repo URL "${config.repoUrl.trim()}" '
        '(provider ${config.provider})',
      );
      throw SyncException(SyncErrorType.unknown, 'Invalid repository URL');
    }
    final gistId = config.gistId.trim();
    log.i(
      '[GitSync] Read snippet: provider=${parsed.provider} '
      'gistId=${gistId.isEmpty ? '<empty>' : gistId} file=${config.filePath}',
    );
    // A blank id (lost by an older build) or a stale id (snippet deleted on
    // the provider) both recover by scanning the account for a snippet
    // carrying the database file. Without this the read path would report
    // "no cloud database" even though one exists.
    final fetched = await _fetchSnippetWithRecovery(config, parsed, gistId);
    if (fetched == null) {
      log.w(
        '[GitSync] Read returns null: no snippet located (stored gistId '
        '${gistId.isEmpty ? '<empty>' : gistId}, account scan found no '
        'snippet with file ${config.filePath})',
      );
      return null;
    }
    // The response is already verified 200 with a JSON object by the
    // fetch/recovery step.
    final (:id, :data) = fetched;
    final filename = config.filePath;
    if (parsed.provider == 'gitlab') {
      // GitLab lists file paths only; fetch the raw endpoint for content.
      final files = data['files'];
      if (files is List) {
        for (final entry in files) {
          if (entry is Map && entry['path'] == filename) {
            return _getGitLabRawFile(config, parsed, id, filename);
          }
        }
      }
      log.w(
        '[GitSync] Read returns null: snippet $id has no file $filename '
        '(GitLab files: ${_fileListSummary(data['files'])})',
      );
      return null;
    }
    final files = data['files'];
    if (files is Map) {
      final file = files[filename];
      if (file is Map) {
        // GitHub/Gitee mark oversized files; refuse rather than corrupting
        // the local copy with partial content.
        if (file['truncated'] == true) {
          throw SyncException(
            SyncErrorType.serverError,
            'Snippet file too large and truncated by the API',
          );
        }
        final content = file['content'];
        if (content is String) return content;
        // Some providers (notably Gitee) 404 the single-gist endpoint but
        // inline everything in the list response; when content is missing
        // here, download the raw_url carried by the file entry.
        final rawUrl = file['raw_url'];
        if (rawUrl is String && rawUrl.isNotEmpty) {
          log.i('[GitSync] File content not inlined — fetching raw_url');
          return _downloadRawContent(config, rawUrl);
        }
        log.w(
          '[GitSync] Read returns null: file $filename exists but content '
          'is not a string (${content.runtimeType})',
        );
      }
    }
    log.w(
      '[GitSync] Read returns null: snippet $id has no file $filename '
      '(files: ${_fileMapSummary(files)})',
    );
    return null;
  }

  /// Compact summaries for diagnostics without dumping file contents.
  String _fileMapSummary(dynamic files) {
    if (files is! Map) return 'unexpected type ${files.runtimeType}';
    return files.keys
        .map((k) => '$k(${files[k] is Map ? 'map' : 'value'})')
        .join(', ');
  }

  String _fileListSummary(dynamic files) {
    if (files is! List) return 'unexpected type ${files.runtimeType}';
    return files
        .map((f) => f is Map ? '${f['path']}(${f.runtimeType})' : '$f')
        .join(', ');
  }

  /// Fetches the snippet, recovering from a blank or stale (deleted)
  /// gist id by scanning the account for a snippet carrying the database
  /// file. Returns null when no snippet can be located at all.
  Future<({String id, Map<String, dynamic> data})?> _fetchSnippetWithRecovery(
    GitSyncConfig config,
    _RepoRef parsed,
    String gistId,
  ) async {
    // The list endpoint is the primary source: it is the only one Gitee
    // serves reliably (the single-snippet endpoint intermittently answers
    // 404/403 for gists the list can see) and it inlines file contents.
    final located = await _findExistingSnippet(config, parsed, gistId);
    if (located == null) return null;
    final (:id, :data) = located;
    if (gistId.isNotEmpty && id != gistId) {
      log.i(
        '[GitSync] Stored gistId $gistId differs from located snippet '
        '$id — persisting',
      );
      final callback = onGistIdCreated;
      if (callback != null) {
        await callback(config.copyWith(gistId: id));
      }
    }
    return (id: id, data: data);
  }

  /// Scans the account's gists/snippets and returns the full list entry for
  /// the snippet carrying the database file (Gitee inlines file contents in
  /// list responses). Prefers the snippet matching [gistId] when present.
  Future<({String id, Map<String, dynamic> data})?> _findExistingSnippet(
    GitSyncConfig config,
    _RepoRef parsed,
    String gistId,
  ) async {
    final filename = config.filePath;
    final isGitLab = parsed.provider == 'gitlab';
    final response = await _withRetry(
      'Git snippet scan',
      () => _get(
        parsed.apiBase,
        isGitLab ? '/snippets?per_page=100' : '/gists?per_page=100',
        config,
      ),
    );
    final data = response.data;
    if (response.statusCode != 200 || data is! List) {
      log.w(
        '[GitSync] List scan failed: HTTP ${response.statusCode} '
        '(type ${data.runtimeType})',
      );
      return null;
    }
    log.i('[GitSync] List scan: ${data.length} snippet(s) listed');
    ({String id, Map<String, dynamic> data})? fallback;
    for (final entry in data) {
      if (entry is! Map) continue;
      final id = entry['id'];
      final files = entry['files'];
      final hasFile = isGitLab
          ? files is List && files.any((f) => f is Map && f['path'] == filename)
          : files is Map && files.containsKey(filename);
      if (!hasFile) continue;
      if (id is String && id == gistId) {
        return (id: id, data: Map<String, dynamic>.from(entry));
      }
      if (fallback == null && id is String && id.isNotEmpty) {
        fallback = (id: id, data: Map<String, dynamic>.from(entry));
      }
    }
    if (fallback != null) {
      log.i(
        '[GitSync] List scan: using snippet ${fallback.id} (stored gistId '
        '${gistId.isEmpty ? '<empty>' : gistId} not found in list)',
      );
    }
    return fallback;
  }

  /// Scans for a snippet id only (used by the upload path's recovery).
  Future<String?> _findExistingSnippetId(
    GitSyncConfig config,
    _RepoRef parsed,
  ) async {
    final located = await _findExistingSnippet(config, parsed, '');
    return located?.id;
  }

  /// Downloads the file content from the raw_url carried by a gist file
  /// entry (used when the provider does not inline content in the list).
  Future<String> _downloadRawContent(
    GitSyncConfig config,
    String rawUrl,
  ) async {
    final response = await _withRetry(
      'Git raw content fetch',
      () => _dio.get<String>(
        rawUrl,
        options: Options(
          headers: _headers(config),
          responseType: ResponseType.plain,
        ),
      ),
    );
    if (response.statusCode != 200 || response.data == null) {
      throw SyncException(
        _typeForStatus(response.statusCode),
        'Raw content HTTP ${response.statusCode ?? 'unknown'}',
      );
    }
    return response.data!;
  }

  Future<String> _getGitLabRawFile(
    GitSyncConfig config,
    _RepoRef parsed,
    String gistId,
    String filename,
  ) async {
    final encoded = Uri.encodeQueryComponent(filename);
    final response = await _withRetry(
      'GitLab raw snippet fetch',
      () => _get(
        parsed.apiBase,
        '/snippets/$gistId/files/main/$encoded/raw',
        config,
      ),
    );
    if (response.statusCode != 200) {
      throw SyncException(
        _typeForStatus(response.statusCode),
        'Raw snippet HTTP ${response.statusCode ?? 'unknown'}',
      );
    }
    final body = response.data;
    if (body is String) return body;
    throw SyncException(SyncErrorType.serverError, 'Unexpected raw response');
  }

  Future<String> _createSnippet(
    GitSyncConfig config,
    _RepoRef parsed,
    String content,
  ) async {
    final filename = config.filePath;
    final isGitLab = parsed.provider == 'gitlab';
    final body = <String, dynamic>{
      if (isGitLab) ...{
        'title': 'KeeStone sync',
        'visibility': 'private',
        'files': [
          {'file_path': filename, 'content': content},
        ],
      } else ...{
        'description': 'KeeStone sync',
        'public': false,
        'files': {
          filename: {'content': content},
        },
        // Gitee v5 takes the token as a body field for gist writes.
        if (parsed.provider == 'gitee') 'access_token': config.token.trim(),
      },
    };
    final response = await _withRetry(
      'Git snippet create',
      () => _post(
        parsed.apiBase,
        isGitLab ? '/snippets' : '/gists',
        config,
        body,
      ),
    );
    final status = response.statusCode;
    if (status != 200 && status != 201) {
      throw SyncException(
        _typeForStatus(status),
        'Snippet create HTTP ${status ?? 'unknown'}',
      );
    }
    final data = response.data;
    final id = data is Map ? data['id'] : null;
    if (id is! String || id.isEmpty) {
      throw SyncException(SyncErrorType.serverError, 'Snippet id missing');
    }
    return id;
  }

  Future<void> _updateSnippet(
    GitSyncConfig config,
    _RepoRef parsed,
    String gistId,
    String content,
  ) async {
    final filename = config.filePath;
    final isGitLab = parsed.provider == 'gitlab';
    final Map<String, dynamic> body;
    if (isGitLab) {
      // GitLab's PUT replaces all snippet content.
      body = {
        'files': [
          {'file_path': filename, 'content': content},
        ],
      };
    } else {
      body = {
        'description': 'KeeStone sync',
        'files': {
          filename: {'content': content},
        },
        if (parsed.provider == 'gitee') 'access_token': config.token.trim(),
      };
    }
    final response = await _withRetry(
      'Git snippet update',
      () => isGitLab
          ? _put(parsed.apiBase, _snippetPath(parsed, gistId), config, body)
          : _patch(parsed.apiBase, _snippetPath(parsed, gistId), config, body),
    );
    final status = response.statusCode;
    if (status != 200) {
      throw SyncException(
        _typeForStatus(status),
        'Snippet update HTTP ${status ?? 'unknown'}',
      );
    }
  }

  String _snippetPath(_RepoRef parsed, String gistId) =>
      parsed.provider == 'gitlab' ? '/snippets/$gistId' : '/gists/$gistId';

  Future<Response<dynamic>> _get(
    String apiBase,
    String path,
    GitSyncConfig config,
  ) {
    // Gitee v5 authenticates via an access_token query parameter instead of
    // an Authorization header.
    final tokenQuery = config.parsedRepo?.provider == 'gitee'
        ? 'access_token=${Uri.encodeQueryComponent(config.token.trim())}'
        : '';
    final joiner = path.contains('?') && tokenQuery.isNotEmpty ? '&' : '';
    return _dio.get<dynamic>(
      '$apiBase$path$joiner$tokenQuery',
      options: Options(headers: _headers(config)),
    );
  }

  Future<Response<dynamic>> _post(
    String apiBase,
    String path,
    GitSyncConfig config,
    Map<String, dynamic> body,
  ) => _send(apiBase, path, config, body, 'post');

  Future<Response<dynamic>> _patch(
    String apiBase,
    String path,
    GitSyncConfig config,
    Map<String, dynamic> body,
  ) => _send(apiBase, path, config, body, 'patch');

  Future<Response<dynamic>> _put(
    String apiBase,
    String path,
    GitSyncConfig config,
    Map<String, dynamic> body,
  ) => _send(apiBase, path, config, body, 'put');

  Future<Response<dynamic>> _send(
    String apiBase,
    String path,
    GitSyncConfig config,
    Map<String, dynamic> body,
    String method,
  ) => _dio.request<dynamic>(
    '$apiBase$path',
    data: body,
    options: Options(method: method, headers: _headers(config)),
  );

  Map<String, String> _headers(GitSyncConfig config) => {
    // Gitee authenticates via query/body token; GitLab via PRIVATE-TOKEN;
    // GitHub via Bearer.
    if (config.parsedRepo?.provider == 'gitlab')
      'PRIVATE-TOKEN': config.token.trim()
    else if (config.parsedRepo?.provider != 'gitee')
      'Authorization': 'Bearer ${config.token.trim()}',
    if (config.parsedRepo?.provider == 'github')
      'Accept': 'application/vnd.github+json',
  };

  /// SHA-1 hex of the stored file content; identical on both sides of the
  /// comparison, so it works as the revision token.
  Future<String> _shaOf(String content) async {
    final digest = await Sha1().hash(utf8.encode(content));
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  SyncErrorType _typeForStatus(int? status) {
    if (status == 401 || status == 403) return SyncErrorType.auth;
    if (status == 404) return SyncErrorType.notFound;
    if (status == 409 || status == 412) return SyncErrorType.conflict;
    if (status != null && status >= 500) return SyncErrorType.serverError;
    return SyncErrorType.unknown;
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
            '$operation failed (attempt ${attempt + 1}/$_maxRetries)',
            error: e,
          );
          if (e is SyncException) rethrow;
          throw SyncException(type, e.toString(), e);
        }
        final delay = _baseDelayMs * pow(2, attempt).toInt();
        log.w('$operation failed, retrying in ${delay}ms: $e');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw lastError!;
  }
}

/// Normalizes a stored revision token. Empty or legacy values map to null
/// ("never seen").
String? normalizeSha(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
