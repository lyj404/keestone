import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/features/audit/data/password_audit_service.dart';

KdbxEntry _entry({
  required String title,
  required String password,
  DateTime? expiry,
  bool expires = false,
}) {
  final db = KdbxDatabase.create(
    credentials: KdbxCredentials(
      password: ProtectedData.fromString('master'),
    ),
    name: 'audit-test',
  );
  final entry = db.createEntry(parent: db.root);
  entry.fields['Title'] = KdbxTextField.fromText(text: title);
  entry.fields['Password'] = KdbxTextField.fromText(
    text: password,
    protected: true,
  );
  entry.times.expires = expires;
  entry.times.expiry = KdbxTime(expires ? expiry : null);
  return entry;
}

void main() {
  const service = PasswordAuditService(
    expiringWindow: Duration(days: 7),
  );
  final now = DateTime(2026, 1, 15);
  String pathOf(KdbxEntry e) => e.parent?.name ?? '';

  test('flags empty, weak, and fair passwords', () {
    final report = service.analyze(
      [
        _entry(title: 'empty', password: ''),
        _entry(title: 'weak', password: 'abc'),
        _entry(title: 'fair', password: 'password1'),
        _entry(title: 'strong', password: 'v9#Qm2!xLp8\$Rw4&Nt6'),
      ],
      groupPathOf: pathOf,
      now: now,
    );

    expect(report.countOf(PasswordIssueKind.empty), 1);
    expect(report.countOf(PasswordIssueKind.weak), 1);
    expect(report.countOf(PasswordIssueKind.fair), 1);
    expect(
      report.findings.any((f) => f.entryUuid.isNotEmpty && f.title == 'strong'),
      isFalse,
    );
    expect(report.healthyEntries, 1);
  });

  test('detects reused passwords without storing them in findings', () {
    final report = service.analyze(
      [
        _entry(title: 'a', password: 'SamePass!234'),
        _entry(title: 'b', password: 'SamePass!234'),
        _entry(title: 'c', password: 'UniquePass!234'),
      ],
      groupPathOf: pathOf,
      now: now,
    );

    final reused = report.findings
        .where((f) => f.kind == PasswordIssueKind.reused)
        .toList();
    expect(reused, hasLength(2));
    expect(reused.every((f) => f.sharedCount == 2), isTrue);
    expect(
      report.findings.any((f) => f.toString().contains('SamePass')),
      isFalse,
    );
  });

  test('detects expired and expiring-soon entries', () {
    final report = service.analyze(
      [
        _entry(
          title: 'past',
          password: 'v9#Qm2!xLp8\$Rw4&Nt6a',
          expires: true,
          expiry: now.subtract(const Duration(days: 1)),
        ),
        _entry(
          title: 'soon',
          password: 'v9#Qm2!xLp8\$Rw4&Nt6b',
          expires: true,
          expiry: now.add(const Duration(days: 3)),
        ),
        _entry(
          title: 'later',
          password: 'v9#Qm2!xLp8\$Rw4&Nt6c',
          expires: true,
          expiry: now.add(const Duration(days: 30)),
        ),
      ],
      groupPathOf: pathOf,
      now: now,
    );

    expect(report.countOf(PasswordIssueKind.expired), 1);
    expect(report.countOf(PasswordIssueKind.expiringSoon), 1);
    expect(report.healthyEntries, 1);
  });

  test('health score is 100 for empty vault and clean entries', () {
    final empty = service.analyze(
      [],
      groupPathOf: pathOf,
      now: now,
    );
    expect(empty.healthScore, 100);

    final clean = service.analyze(
      [_entry(title: 'ok', password: 'v9#Qm2!xLp8\$Rw4&Nt6')],
      groupPathOf: pathOf,
      now: now,
    );
    expect(clean.healthScore, 100);
    expect(clean.hasIssues, isFalse);
  });

  test('sorts critical findings first', () {
    final report = service.analyze(
      [
        _entry(title: 'z-weak', password: 'abc'),
        _entry(title: 'a-empty', password: ''),
        _entry(
          title: 'm-expired',
          password: 'v9#Qm2!xLp8\$Rw4&Nt6z',
          expires: true,
          expiry: now.subtract(const Duration(days: 2)),
        ),
      ],
      groupPathOf: pathOf,
      now: now,
    );

    expect(
      report.findings.first.kind,
      PasswordIssueKind.empty,
    );
    expect(
      report.findings.map((f) => f.kind).toList(),
      containsAllInOrder([
        PasswordIssueKind.empty,
        PasswordIssueKind.expired,
        PasswordIssueKind.weak,
      ]),
    );
  });
}
