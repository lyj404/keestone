import 'dart:convert';

/// AWS "strict" URI encoding for canonical request components: everything
/// except the unreserved characters is percent-encoded with uppercase hex,
/// operating on UTF-8 bytes. Used for object key path segments.
String awsUriEncode(String component) {
  final buffer = StringBuffer();
  for (final byte in utf8.encode(component)) {
    final ch = String.fromCharCode(byte);
    if ((byte >= 0x41 && byte <= 0x5a) ||
        (byte >= 0x61 && byte <= 0x7a) ||
        (byte >= 0x30 && byte <= 0x39) ||
        ch == '-' ||
        ch == '.' ||
        ch == '_' ||
        ch == '~') {
      buffer.write(ch);
    } else {
      buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return buffer.toString();
}

/// Percent-encodes an object key for a request URL / canonical URI, keeping
/// the `/` separators unencoded (S3 canonical URIs encode per segment).
String encodeS3KeyPath(String key) =>
    key.split('/').map(awsUriEncode).join('/');

/// Configuration for one S3-compatible sync profile (AWS S3, MinIO, R2,
/// B2's S3 API, OSS, COS, …).
///
/// Like the Git backend, sync talks plain HTTPS to the remote service —
/// here the S3 REST API with Signature V4 — so the behavior, conflict
/// detection, and metadata reuse of the WebDAV backend carry over.
class S3SyncConfig {
  final String id;
  final String name;

  /// Service endpoint, e.g. https://s3.us-east-1.amazonaws.com or
  /// https://play.min.io. Must be a valid http(s) URL.
  final String endpoint;

  /// AWS region for signing (e.g. us-east-1). Some S3-compatible services
  /// accept any non-empty value; MinIO commonly uses us-east-1.
  final String region;

  final String bucket;

  /// Access key id / secret access key pair. An optional session token
  /// covers temporary (STS) credentials.
  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;

  /// Key prefix (folder) for the database inside the bucket. Empty stores
  /// it at the bucket root.
  final String remotePath;

  final String remoteFilename;

  /// Path-style addressing (https://host/bucket/key). Defaults to true
  /// because most self-hosted S3-compatible services (MinIO, Ceph) require
  /// it; AWS S3 still accepts it. Virtual-host style needs a wildcard TLS
  /// certificate on the endpoint host.
  final bool usePathStyle;

  final bool enabled;

  const S3SyncConfig({
    required this.id,
    required this.name,
    this.endpoint = '',
    this.region = '',
    this.bucket = '',
    this.accessKeyId = '',
    this.secretAccessKey = '',
    this.sessionToken = '',
    this.remotePath = '',
    this.remoteFilename = 'database.kdbx',
    this.usePathStyle = true,
    this.enabled = false,
  });

  /// Validates and normalizes the configured endpoint. Only S3 over HTTP or
  /// HTTPS is supported. Callers should warn before using insecure HTTP.
  Uri get endpointUri {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('S3 endpoint must use http or https');
    }
    return uri;
  }

  bool get usesInsecureHttp => endpointUri.scheme == 'http';

  /// The object key the database is stored under: [remotePath] prefix plus
  /// [remoteFilename], with redundant separators collapsed.
  String get objectKey {
    var prefix = remotePath.trim().replaceAll(RegExp(r'/+'), '/');
    if (prefix.startsWith('/')) prefix = prefix.substring(1);
    if (prefix.endsWith('/')) {
      prefix = prefix.substring(0, prefix.length - 1);
    }
    final name = remoteFilename.trim().isEmpty
        ? 'database.kdbx'
        : remoteFilename.trim();
    return prefix.isEmpty ? name : '$prefix/$name';
  }

  /// The request host (and, for virtual-host style, the bucket-prefixed
  /// host) used both for the URL and the signed Host header.
  String requestHost() {
    final uri = endpointUri;
    if (usePathStyle) return uri.authority;
    return '${bucket.trim().toLowerCase()}.${uri.authority}';
  }

  /// The absolute request path for [key] (null = bucket-level operation),
  /// already percent-encoded. This string is sent on the wire AND used as
  /// the SigV4 canonical URI, so the signed path is byte-identical to the
  /// path the server sees. For path-style addressing the bucket is part of
  /// the path; for virtual-host style it lives in the host instead.
  String requestPath(String? key) {
    final objectPath = key == null ? '/' : '/${encodeS3KeyPath(key)}';
    return usePathStyle ? '/${bucket.trim()}$objectPath' : objectPath;
  }

  /// Builds the request URL from a path produced by [requestPath]. The path
  /// is never re-encoded or normalized here: the SigV4 canonical URI must
  /// stay byte-identical to the path sent on the wire.
  String requestUrl(String encodedPath) =>
      '${endpointUri.scheme}://${requestHost()}$encodedPath';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'endpoint': endpoint,
    'region': region,
    'bucket': bucket,
    'accessKeyId': accessKeyId,
    'secretAccessKey': secretAccessKey,
    'sessionToken': sessionToken,
    'remotePath': remotePath,
    'remoteFilename': remoteFilename,
    'usePathStyle': usePathStyle,
    'enabled': enabled,
  };

  factory S3SyncConfig.fromJson(Map<String, dynamic> json) => S3SyncConfig(
    id: json['id'] as String? ?? _generateId(),
    name: json['name'] as String? ?? 'S3',
    endpoint: json['endpoint'] as String? ?? '',
    region: json['region'] as String? ?? '',
    bucket: json['bucket'] as String? ?? '',
    accessKeyId: json['accessKeyId'] as String? ?? '',
    secretAccessKey: json['secretAccessKey'] as String? ?? '',
    sessionToken: json['sessionToken'] as String? ?? '',
    remotePath: json['remotePath'] as String? ?? '',
    remoteFilename: json['remoteFilename'] as String? ?? 'database.kdbx',
    usePathStyle: json['usePathStyle'] as bool? ?? true,
    enabled: json['enabled'] as bool? ?? false,
  );

  String encode() => jsonEncode(toJson());

  factory S3SyncConfig.decode(String source) =>
      S3SyncConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  S3SyncConfig copyWith({
    String? id,
    String? name,
    String? endpoint,
    String? region,
    String? bucket,
    String? accessKeyId,
    String? secretAccessKey,
    String? sessionToken,
    String? remotePath,
    String? remoteFilename,
    bool? usePathStyle,
    bool? enabled,
  }) => S3SyncConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    endpoint: endpoint ?? this.endpoint,
    region: region ?? this.region,
    bucket: bucket ?? this.bucket,
    accessKeyId: accessKeyId ?? this.accessKeyId,
    secretAccessKey: secretAccessKey ?? this.secretAccessKey,
    sessionToken: sessionToken ?? this.sessionToken,
    remotePath: remotePath ?? this.remotePath,
    remoteFilename: remoteFilename ?? this.remoteFilename,
    usePathStyle: usePathStyle ?? this.usePathStyle,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is S3SyncConfig &&
          id == other.id &&
          name == other.name &&
          endpoint == other.endpoint &&
          region == other.region &&
          bucket == other.bucket &&
          accessKeyId == other.accessKeyId &&
          secretAccessKey == other.secretAccessKey &&
          sessionToken == other.sessionToken &&
          remotePath == other.remotePath &&
          remoteFilename == other.remoteFilename &&
          usePathStyle == other.usePathStyle &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    endpoint,
    region,
    bucket,
    accessKeyId,
    secretAccessKey,
    sessionToken,
    remotePath,
    remoteFilename,
    usePathStyle,
    enabled,
  );

  static String _generateId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 's3_$micros';
  }
}
