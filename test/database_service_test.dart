import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/features/database/data/database_service.dart';

void main() {
  group('DatabaseService lifecycle and search', () {
    late Directory directory;
    late String databasePath;
    late DatabaseService service;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('keestone_database_');
      databasePath = '${directory.path}${Platform.pathSeparator}vault.kdbx';
      service = DatabaseService();
    });

    tearDown(() async {
      if (service.isOpen) service.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('creates, indexes, searches, and closes a database', () async {
      await service.createDatabase('Test vault', 'test-password', databasePath);
      final root = service.db!.root;
      final entry = service.createEntry(root);
      entry.fields['Title'] = KdbxTextField.fromText(text: 'GitHub');
      entry.fields['UserName'] = KdbxTextField.fromText(
        text: 'alice@example.com',
      );
      service.rebuildEntryCache();

      final results = service.search('git');
      expect(results, hasLength(1));
      expect(results.single.entry, same(entry));

      entry.fields['Title'] = KdbxTextField.fromText(text: 'GitLab');
      service.rebuildEntryCache();
      expect(service.search('github'), isEmpty);
      expect(service.search('gitlab'), hasLength(1));

      service.close();
      expect(service.isOpen, isFalse);
      expect(service.allEntries, isEmpty);
    });

    test(
      'persists entries and reopens them with the master password',
      () async {
        await service.createDatabase(
          'Test vault',
          'test-password',
          databasePath,
        );
        final entry = service.createEntry(service.db!.root);
        entry.fields['Title'] = KdbxTextField.fromText(text: 'Saved account');
        entry.fields['URL'] = KdbxTextField.fromText(
          text: 'https://example.com',
        );
        service.rebuildEntryCache();

        final bytes = await service.saveToBytes();
        await File(databasePath).writeAsBytes(bytes, flush: true);
        service.close();
        await service.openFile(databasePath, 'test-password');

        final results = service.search('example.com');
        expect(results, hasLength(1));
        expect(results.single.entry.fields['Title']?.text, 'Saved account');
        expect(service.isDirty, isFalse);
      },
    );

    test(
      'invalidates the old master password after a password change',
      () async {
        await service.createDatabase(
          'Test vault',
          'old-password',
          databasePath,
        );
        service.changePassword('old-password', 'new-password');
        final bytes = await service.saveToBytes();
        await File(databasePath).writeAsBytes(bytes, flush: true);
        service.close();

        await expectLater(
          service.openFile(databasePath, 'old-password'),
          throwsA(isA<InvalidCredentialsError>()),
        );
        expect(service.isOpen, isFalse);

        await service.openFile(databasePath, 'new-password');
        expect(service.isOpen, isTrue);
        expect(service.isDirty, isFalse);
      },
    );

    test('sync audit masks password and protected field values', () async {
      await service.createDatabase('Test vault', 'master', databasePath);
      final entry = service.createEntry(service.db!.root);
      entry.fields['Title'] = KdbxTextField.fromText(text: 'Secret account');
      entry.fields['Password'] = KdbxTextField.fromText(
        text: 'local-super-secret',
        protected: true,
      );
      entry.fields['API Token'] = KdbxTextField.fromText(
        text: 'local-token-secret',
        protected: true,
      );
      entry.fields['UserName'] = KdbxTextField.fromText(text: 'alice');
      service.rebuildEntryCache();

      final localBytes = await service.saveToBytes();
      // Mutate only protected fields on the local copy, then build a remote
      // database that still has the older values.
      entry.fields['Password'] = KdbxTextField.fromText(
        text: 'remote-super-secret',
        protected: true,
      );
      entry.fields['API Token'] = KdbxTextField.fromText(
        text: 'remote-token-secret',
        protected: true,
      );
      entry.fields['UserName'] = KdbxTextField.fromText(text: 'alice');
      service.markDirty();
      service.rebuildEntryCache();

      final report = await service.buildSyncAuditReportFromBytes(localBytes);
      expect(report.modifiedBoth, hasLength(1));
      final change = report.modifiedBoth.single;
      final joined = [
        ...change.localValues.values,
        ...change.remoteValues.values,
      ].join(' ');
      expect(joined, isNot(contains('local-super-secret')));
      expect(joined, isNot(contains('remote-super-secret')));
      expect(joined, isNot(contains('local-token-secret')));
      expect(joined, isNot(contains('remote-token-secret')));
      expect(
        change.localValues['Password'],
        DatabaseService.maskedAuditValue,
      );
      expect(
        change.remoteValues['Password'],
        DatabaseService.maskedAuditValue,
      );
    });
  });
}
