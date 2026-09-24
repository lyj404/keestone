import 'package:kpasslib/kpasslib.dart';

import '../../../core/utils/password_strength.dart';

/// A single password-health problem found on an entry.
enum PasswordIssueKind {
  /// Password field is empty.
  empty,

  /// Strength scored [PasswordStrengthLevel.weak].
  weak,

  /// Strength scored [PasswordStrengthLevel.fair].
  fair,

  /// Same password string is used by two or more entries.
  reused,

  /// Expiry date is in the past.
  expired,

  /// Expiry date is within [PasswordAuditService.expiringWindow].
  expiringSoon,
}

extension PasswordIssueKindSeverity on PasswordIssueKind {
  /// Lower rank sorts first (more urgent).
  int get severityRank {
    switch (this) {
      case PasswordIssueKind.empty:
        return 0;
      case PasswordIssueKind.expired:
        return 1;
      case PasswordIssueKind.weak:
        return 2;
      case PasswordIssueKind.reused:
        return 3;
      case PasswordIssueKind.fair:
        return 4;
      case PasswordIssueKind.expiringSoon:
        return 5;
    }
  }
}

/// One audit hit. Never carries the plaintext password.
class PasswordAuditFinding {
  final String entryUuid;
  final String title;
  final String groupPath;
  final PasswordIssueKind kind;
  final PasswordStrengthLevel? strength;
  final DateTime? expiry;
  final int sharedCount;

  const PasswordAuditFinding({
    required this.entryUuid,
    required this.title,
    required this.groupPath,
    required this.kind,
    this.strength,
    this.expiry,
    this.sharedCount = 1,
  });

  @override
  String toString() => 'PasswordAuditFinding($kind, title: $title)';
}

class PasswordAuditReport {
  final int totalEntries;
  final int healthyEntries;
  final List<PasswordAuditFinding> findings;
  final DateTime scannedAt;

  const PasswordAuditReport({
    required this.totalEntries,
    required this.healthyEntries,
    required this.findings,
    required this.scannedAt,
  });

  int countOf(PasswordIssueKind kind) =>
      findings.where((f) => f.kind == kind).length;

  int get issueEntryCount => findings.map((f) => f.entryUuid).toSet().length;

  bool get hasIssues => findings.isNotEmpty;

  /// 0–100; 100 means every scanned entry has no findings.
  int get healthScore {
    if (totalEntries == 0) return 100;
    return ((healthyEntries / totalEntries) * 100).round();
  }
}

/// Pure-local vault password health scan (no network, no plaintext in output).
class PasswordAuditService {
  const PasswordAuditService({
    this.expiringWindow = const Duration(days: 7),
  });

  /// How soon an expiry counts as "expiring soon".
  final Duration expiringWindow;

  /// Scans [entries]. [groupPathOf] resolves the display path for an entry.
  PasswordAuditReport analyze(
    List<KdbxEntry> entries, {
    required String Function(KdbxEntry entry) groupPathOf,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final reuseBuckets = <String, List<KdbxEntry>>{};
    final passwordOf = <String, String>{};

    for (final entry in entries) {
      final password = entry.fields['Password']?.text ?? '';
      passwordOf[entry.uuid.string] = password;
      if (password.isEmpty) continue;
      reuseBuckets.putIfAbsent(password, () => []).add(entry);
    }

    final reuseCount = <String, int>{};
    for (final bucket in reuseBuckets.values) {
      if (bucket.length < 2) continue;
      for (final e in bucket) {
        reuseCount[e.uuid.string] = bucket.length;
      }
    }

    final findings = <PasswordAuditFinding>[];
    var healthy = 0;

    for (final entry in entries) {
      final uuid = entry.uuid.string;
      final title = entry.fields['Title']?.text ?? '';
      final path = groupPathOf(entry);
      final password = passwordOf[uuid] ?? '';
      final entryFindings = <PasswordAuditFinding>[];

      PasswordAuditFinding finding(
        PasswordIssueKind kind, {
        PasswordStrengthLevel? strength,
        DateTime? expiry,
        int? sharedCount,
      }) {
        return PasswordAuditFinding(
          entryUuid: uuid,
          title: title,
          groupPath: path,
          kind: kind,
          strength: strength,
          expiry: expiry,
          sharedCount: sharedCount ?? 1,
        );
      }

      if (password.isEmpty) {
        entryFindings.add(finding(PasswordIssueKind.empty));
      } else {
        final strength = evaluatePasswordStrength(password);
        if (strength == PasswordStrengthLevel.weak) {
          entryFindings.add(
            finding(PasswordIssueKind.weak, strength: strength),
          );
        } else if (strength == PasswordStrengthLevel.fair) {
          entryFindings.add(
            finding(PasswordIssueKind.fair, strength: strength),
          );
        }
        final shared = reuseCount[uuid];
        if (shared != null && shared > 1) {
          entryFindings.add(
            finding(PasswordIssueKind.reused, sharedCount: shared),
          );
        }
      }

      if (entry.times.expires) {
        final expiry = entry.times.expiry.time;
        if (expiry != null) {
          if (expiry.isBefore(clock)) {
            entryFindings.add(
              finding(PasswordIssueKind.expired, expiry: expiry),
            );
          } else if (expiry.isBefore(clock.add(expiringWindow))) {
            entryFindings.add(
              finding(PasswordIssueKind.expiringSoon, expiry: expiry),
            );
          }
        }
      }

      if (entryFindings.isEmpty) {
        healthy++;
      } else {
        findings.addAll(entryFindings);
      }
    }

    findings.sort((a, b) {
      final byKind = a.kind.severityRank.compareTo(b.kind.severityRank);
      if (byKind != 0) return byKind;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return PasswordAuditReport(
      totalEntries: entries.length,
      healthyEntries: healthy,
      findings: findings,
      scannedAt: clock,
    );
  }
}
