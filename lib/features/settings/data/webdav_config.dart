import 'dart:convert';

class WebDavConfig {
  final String id;
  final String name;
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final String remoteFilename;
  final bool enabled;

  const WebDavConfig({
    required this.id,
    required this.name,
    required this.serverUrl,
    this.username = '',
    this.password = '',
    this.remotePath = '',
    this.remoteFilename = 'database.kdbx',
    this.enabled = false,
  });

  /// Builds the full remote file path for WebDAV operations.
  /// If remotePath is empty, only the filename is used (relative to server URL).
  /// Validates and normalizes the configured endpoint. Only WebDAV over HTTP
  /// or HTTPS is supported. Callers should warn before using insecure HTTP.
  Uri get serverUri {
    final uri = Uri.tryParse(serverUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('WebDAV URL must use http or https');
    }
    return uri;
  }

  bool get usesInsecureHttp => serverUri.scheme == 'http';
  String get remoteFilePath {
    final path = remotePath.trim();
    final name = remoteFilename.trim();
    if (path.isEmpty) return '/$name';
    return '$path/$name';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'remotePath': remotePath,
    'remoteFilename': remoteFilename,
    'enabled': enabled,
  };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
    id: json['id'] as String? ?? _generateId(),
    name: json['name'] as String? ?? 'Profile',
    serverUrl: json['serverUrl'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    remotePath: json['remotePath'] as String? ?? '',
    remoteFilename: json['remoteFilename'] as String? ?? 'database.kdbx',
    enabled: json['enabled'] as bool? ?? false,
  );

  String encode() => jsonEncode(toJson());

  factory WebDavConfig.decode(String source) =>
      WebDavConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  WebDavConfig copyWith({
    String? id,
    String? name,
    String? serverUrl,
    String? username,
    String? password,
    String? remotePath,
    String? remoteFilename,
    bool? enabled,
  }) => WebDavConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    serverUrl: serverUrl ?? this.serverUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    remotePath: remotePath ?? this.remotePath,
    remoteFilename: remoteFilename ?? this.remoteFilename,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebDavConfig &&
          id == other.id &&
          name == other.name &&
          serverUrl == other.serverUrl &&
          username == other.username &&
          password == other.password &&
          remotePath == other.remotePath &&
          remoteFilename == other.remoteFilename &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    serverUrl,
    username,
    password,
    remotePath,
    remoteFilename,
    enabled,
  );

  static String _generateId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'webdav_$micros';
  }
}

class WebDavProfilesState {
  final List<WebDavConfig> profiles;
  final String? activeProfileId;

  const WebDavProfilesState({
    required this.profiles,
    required this.activeProfileId,
  });

  WebDavConfig? get activeProfile {
    if (activeProfileId == null) return null;
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  Map<String, dynamic> toJson() => {
    'activeProfileId': activeProfileId,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
  };

  factory WebDavProfilesState.fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'];
    final profiles = rawProfiles is List
        ? rawProfiles
              .whereType<Map<String, dynamic>>()
              .map(WebDavConfig.fromJson)
              .toList()
        : <WebDavConfig>[];
    final activeProfileId = json['activeProfileId'] as String?;
    return WebDavProfilesState(
      profiles: profiles,
      activeProfileId: activeProfileId,
    );
  }

  String encode() => jsonEncode(toJson());

  factory WebDavProfilesState.decode(String source) =>
      WebDavProfilesState.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

