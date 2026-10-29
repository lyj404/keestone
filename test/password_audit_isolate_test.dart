import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/features/audit/data/password_audit_service.dart';
import 'package:keestone/features/database/data/database_service.dart';

void main() {
  test('audit snapshot pipeline survives Isolate.run with a live vault', () async {
    final directory = await Directory.systemTemp.createTemp('keestone_audit_');
    final service = DatabaseService();
    addTearDown(() {
      if (service.isOpen) service.close();
      directory.delete(recursive: true);
    });

    final databasePath = '${directory.path}${Platform.pathSeparator}vault.kdbx';
    await service.createDatabase('Vault', 'test-password', databasePath);
    final entry = service.createEntry(service.db!.root);
    entry.fields['Title'] = KdbxTextField.fromText(text: 'GitHub');
    entry.fields['UserName'] = KdbxTextField.fromText(text: 'alice@example.com');
    entry.fields['Password'] = KdbxTextField.fromText(
      text: 'xK9#mP2\$vL8qW4zR',
    );
    service.rebuildEntryCache();

    // Mirrors _rescan in PasswordAuditScreen.
    final data = [
      for (final e in service.allEntries)
        if (!service.isInRecycleBin(e))
          PasswordAuditEntryData(
            uuid: e.uuid.string,
            title: e.fields['Title']?.text ?? '',
            groupPath: e.parent == null ? '' : service.getGroupPath(e.parent!),
            password: e.fields['Password']?.text ?? '',
            expires: e.times.expires,
            expiry: e.times.expiry.time,
          ),
    ];

    final report = await analyzePasswordAuditSnapshots(data);

    expect(report.totalEntries, 1);
    expect(report.findings, isEmpty);
  });
}
