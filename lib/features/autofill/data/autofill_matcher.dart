import 'dart:math';

import 'package:kpasslib/kpasslib.dart';

/// A minimal, serializable view of a vault entry for the autofill bridge.
///
/// The native autofill service receives these as a JSON array and renders the
/// system dataset picker (only [title]/[username]/[subtitle] are displayed).
/// [password] is included so the dataset can pre-fill both fields on tap; it
/// never appears in the picker UI.
class AutofillCandidate {
  final String uuid;
  final String title;
  final String username;
  final String password;
  final String subtitle;

  const AutofillCandidate({
    required this.uuid,
    required this.title,
    required this.username,
    required this.password,
    required this.subtitle,
  });

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'title': title,
    'username': username,
    'password': password,
    'subtitle': subtitle,
  };
}

/// Result of an autofill credential lookup.
class AutofillMatchResult {
  final List<AutofillCandidate> candidates;
  final bool isLocked;
  final String? filePath;

  const AutofillMatchResult.unlocked(this.candidates)
    : isLocked = false,
      filePath = null;

  const AutofillMatchResult.locked({this.filePath})
    : candidates = const [],
      isLocked = true;

  Map<String, dynamic> toJson() => {
    'status': isLocked ? 'locked' : 'unlocked',
    if (filePath != null) 'filePath': filePath,
    'candidates': candidates.map((c) => c.toJson()).toList(),
  };
}

/// Parsed autofill query: an Android package id and/or a web domain.
class AutofillQuery {
  final String? packageId;
  final String? domain;

  const AutofillQuery({this.packageId, this.domain});

  bool get isEmpty => (packageId == null || packageId!.isEmpty) &&
      (domain == null || domain!.isEmpty);
}

/// Matches vault entries against an autofill request.
///
/// Matching rules (URL field of each entry):
///   * `https://example.com/login`        → host `example.com`
///   * `androidapp://com.example.app`     → Android package id
///   * Multiple URLs separated by `;` / newline are all considered.
///   * An exact host match (e.g. `example.com`) wins over a suffix match
///     (`login.example.com` matches `example.com`); subdomain matches sort last.
class AutofillMatcher {
  /// Parses a raw URL field value into the list of comparison tokens it yields.
  /// Visible for testing. Each token is `(value, isPackage)`.
  static List<({String value, bool isPackage})> parseUrlField(String raw) {
    final tokens = <({String value, bool isPackage})>[];
    for (final part in raw.split(RegExp(r'[;\n\r]'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final uri = Uri.tryParse(trimmed);
      if (uri == null) continue;
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'androidapp') {
        final pkg = (uri.host.isNotEmpty ? uri.host : uri.path)
            .replaceAll('/', '')
            .toLowerCase();
        if (pkg.isNotEmpty) tokens.add((value: pkg, isPackage: true));
        continue;
      }
      final host = uri.host.toLowerCase();
      if (host.isEmpty) continue;
      tokens.add((value: host, isPackage: false));
    }
    return tokens;
  }

  /// Returns candidates ranked best-first. Recycle-bin entries are excluded.
  static List<AutofillCandidate> match(
    Iterable<KdbxEntry> entries, {
    required bool Function(KdbxItem) isInRecycleBin,
    required AutofillQuery query,
    int limit = 20,
  }) {
    if (query.isEmpty) return const [];

    final lowerDomain = query.domain?.toLowerCase();
    final lowerPackage = query.packageId?.toLowerCase();

    final scored = <_Scored>[];
    for (final entry in entries) {
      if (isInRecycleBin(entry)) continue;
      final urlRaw = entry.fields['URL']?.text ?? '';
      final tokens = parseUrlField(urlRaw);
      if (tokens.isEmpty) continue;

      int bestScore = 0;
      for (final t in tokens) {
        if (t.isPackage && lowerPackage != null) {
          if (t.value == lowerPackage) {
            bestScore = max(bestScore, 100);
          } else if (lowerPackage.endsWith('.${t.value}') ||
              t.value.endsWith('.$lowerPackage')) {
            bestScore = max(bestScore, 40);
          }
        }
        if (!t.isPackage && lowerDomain != null) {
          if (t.value == lowerDomain) {
            bestScore = max(bestScore, 100);
          } else if (lowerDomain.endsWith('.${t.value}') ||
              t.value.endsWith('.$lowerDomain')) {
            // subdomain / parent-domain overlap
            bestScore = max(bestScore, 60);
          }
        }
      }
      if (bestScore == 0) continue;
      scored.add(_Scored(entry, bestScore));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final take = scored.length > limit ? scored.sublist(0, limit) : scored;
    return take.map((s) => _candidate(s.entry)).toList(growable: false);
  }

  static AutofillCandidate _candidate(KdbxEntry entry) {
    final title = entry.fields['Title']?.text ?? '';
    final username = entry.fields['UserName']?.text ?? '';
    final password = entry.fields['Password']?.text ?? '';
    final groupPath = _groupPath(entry);
    final subtitle = groupPath.isEmpty
        ? (title.isEmpty ? username : title)
        : groupPath;
    return AutofillCandidate(
      uuid: entry.uuid.string,
      title: title,
      username: username,
      password: password,
      subtitle: subtitle,
    );
  }

  static String _groupPath(KdbxEntry entry) {
    final parts = <String>[];
    var g = entry.parent;
    while (g != null && g.parent != null) {
      parts.insert(0, g.name);
      g = g.parent;
    }
    return parts.join('/');
  }
}

class _Scored {
  final KdbxEntry entry;
  final int score;
  const _Scored(this.entry, this.score);
}
