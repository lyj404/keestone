import 'dart:convert';

/// Configuration for one Git-based sync profile.
///
/// Sync talks to the Git hosting provider's HTTP API (GitHub, Gitee, or
/// GitLab), not to a local git binary, so the behavior, conflict detection,
/// and metadata reuse of the WebDAV backend carry over.
class GitSyncConfig {
  /// Backend selector values, persisted with the profile.
  static const supportedProviders = ['github', 'gitee', 'gitlab'];

  final String id;
  final String name;
  final String provider;

  /// Site URL used to locate the provider's API. GitHub and Gitee have
  /// fixed API bases, so this can stay empty there; a self-hosted GitLab
  /// needs its own host (e.g. https://gitlab.example.com).
  final String repoUrl;

  /// Branch to sync. Empty means the repository's default branch.
  final String branch;

  /// Gist (GitHub/Gitee) or snippet (GitLab) id that stores the database.
  /// Empty until the first successful push creates it; kept as a plain
  /// non-secret string — access still requires the token.
  final String gistId;

  /// Personal access token with contents read/write permission.
  final String token;

  /// File name of the database inside the gist/snippet, e.g. database.kdbx.
  final String remoteFilename;
  final bool enabled;

  const GitSyncConfig({
    required this.id,
    required this.name,
    this.provider = 'github',
    this.repoUrl = '',
    this.branch = '',
    this.gistId = '',
    this.token = '',
    this.remoteFilename = 'database.kdbx',
    this.enabled = false,
  });

  /// Resolves the API base from [repoUrl] and [provider]. GitHub and Gitee
  /// use fixed API bases; a self-hosted GitLab needs a valid [repoUrl] from
  /// which the API host is derived.
  ({String apiBase, String provider})? get parsedRepo {
    final effectiveProvider = supportedProviders.contains(provider)
        ? provider
        : 'github';
    final apiBase = switch (effectiveProvider) {
      'github' => 'https://api.github.com',
      'gitee' => 'https://gitee.com/api/v5',
      _ => _gitLabApiBase(),
    };
    if (apiBase == null) return null;
    return (
      apiBase: apiBase,
      provider: effectiveProvider,
    );
  }

  /// Derives the GitLab API base from [repoUrl], or null when it is not a
  /// usable http(s) URL.
  String? _gitLabApiBase() {
    final uri = Uri.tryParse(repoUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/api/v4';
  }

  String get filePath {
    final name = remoteFilename.trim();
    if (name.isEmpty) return 'database.kdbx';
    return name.startsWith('/') ? name.substring(1) : name;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'repoUrl': repoUrl,
    'branch': branch,
    'gistId': gistId,
    'token': token,
    'remoteFilename': remoteFilename,
    'enabled': enabled,
  };

  factory GitSyncConfig.fromJson(Map<String, dynamic> json) => GitSyncConfig(
    id: json['id'] as String? ?? _generateId(),
    name: json['name'] as String? ?? 'Profile',
    provider: json['provider'] as String? ?? 'github',
    repoUrl: json['repoUrl'] as String? ?? '',
    branch: json['branch'] as String? ?? '',
    gistId: json['gistId'] as String? ?? '',
    token: json['token'] as String? ?? '',
    remoteFilename: json['remoteFilename'] as String? ?? 'database.kdbx',
    enabled: json['enabled'] as bool? ?? false,
  );

  String encode() => jsonEncode(toJson());

  factory GitSyncConfig.decode(String source) =>
      GitSyncConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  GitSyncConfig copyWith({
    String? id,
    String? name,
    String? provider,
    String? repoUrl,
    String? branch,
    String? gistId,
    String? token,
    String? remoteFilename,
    bool? enabled,
  }) => GitSyncConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    provider: provider ?? this.provider,
    repoUrl: repoUrl ?? this.repoUrl,
    branch: branch ?? this.branch,
    gistId: gistId ?? this.gistId,
    token: token ?? this.token,
    remoteFilename: remoteFilename ?? this.remoteFilename,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitSyncConfig &&
          id == other.id &&
          name == other.name &&
          provider == other.provider &&
          repoUrl == other.repoUrl &&
          branch == other.branch &&
          gistId == other.gistId &&
          token == other.token &&
          remoteFilename == other.remoteFilename &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    provider,
    repoUrl,
    branch,
    gistId,
    token,
    remoteFilename,
    enabled,
  );

  static String _generateId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'git_$micros';
  }
}
