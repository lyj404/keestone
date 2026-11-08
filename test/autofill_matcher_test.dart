import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/features/autofill/data/autofill_matcher.dart';

void main() {
  group('AutofillMatcher.parseUrlField', () {
    test('parses https domain hosts', () {
      final tokens = AutofillMatcher.parseUrlField(
        'https://example.com/login',
      );
      expect(tokens, [
        (value: 'example.com', isPackage: false),
      ]);
    });

    test('parses multiple URLs separated by ; or newline', () {
      final tokens = AutofillMatcher.parseUrlField(
        'https://a.com\nhttps://b.com/login;androidapp://com.foo',
      );
      expect(tokens, [
        (value: 'a.com', isPackage: false),
        (value: 'b.com', isPackage: false),
        (value: 'com.foo', isPackage: true),
      ]);
    });

    test('ignores bare strings without a scheme/host', () {
      expect(AutofillMatcher.parseUrlField('not a url'), isEmpty);
      expect(AutofillMatcher.parseUrlField('https://'), isEmpty);
      expect(AutofillMatcher.parseUrlField(''), isEmpty);
    });

    test('androidapp package may appear in host or path', () {
      expect(
        AutofillMatcher.parseUrlField('androidapp://com.example.app'),
        [(value: 'com.example.app', isPackage: true)],
      );
      expect(
        AutofillMatcher.parseUrlField('androidapp:com.example.app'),
        [(value: 'com.example.app', isPackage: true)],
      );
    });
  });

  group('AutofillMatcher.match', () {
    late KdbxDatabase db;
    late bool Function(KdbxItem) isInRecycleBin;

    setUp(() {
      db = KdbxDatabase.create(
        credentials: KdbxCredentials(
          password: ProtectedData.fromString('test'),
        ),
        name: 'test',
      );
      // No recycle bin filtering: nothing is ever "in recycle bin".
      isInRecycleBin = (_) => false;
    });

    KdbxEntry makeEntry({
      String title = '',
      String username = '',
      String url = '',
    }) {
      final entry = db.createEntry(parent: db.root);
      if (title.isNotEmpty) {
        entry.fields['Title'] = KdbxTextField.fromText(text: title);
      }
      if (username.isNotEmpty) {
        entry.fields['UserName'] = KdbxTextField.fromText(text: username);
      }
      if (url.isNotEmpty) {
        entry.fields['URL'] = KdbxTextField.fromText(text: url);
      }
      return entry;
    }

    test('matches by exact domain host', () {
      final e = makeEntry(
        title: 'GitHub',
        username: 'alice@example.com',
        url: 'https://github.com/login',
      );
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(domain: 'github.com'),
      );
      expect(result, hasLength(1));
      expect(result.first.uuid, e.uuid.string);
      expect(result.first.title, 'GitHub');
      expect(result.first.username, 'alice@example.com');
    });

    test('ranks exact host above subdomain overlap', () {
      makeEntry(title: 'Login', url: 'https://login.example.com');
      makeEntry(title: 'Root', url: 'https://example.com');
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(domain: 'example.com'),
      );
      expect(result.first.title, 'Root');
      expect(result, hasLength(2));
    });

    test('matches subdomain request against parent-domain entry', () {
      makeEntry(title: 'Wide', url: 'https://example.com');
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(domain: 'login.example.com'),
      );
      expect(result, hasLength(1));
      expect(result.first.title, 'Wide');
    });

    test('matches androidapp:// scheme against package id', () {
      makeEntry(title: 'App', url: 'androidapp://com.example.app');
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(packageId: 'com.example.app'),
      );
      expect(result, hasLength(1));
      expect(result.first.title, 'App');
    });

    test('does not cross-match package id against web domain', () {
      makeEntry(title: 'App', url: 'androidapp://com.example.app');
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(domain: 'com.example.app'),
      );
      expect(result, isEmpty);
    });

    test('excludes entries with no URL field', () {
      makeEntry(title: 'NoUrl', username: 'u');
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(domain: 'anything.com'),
      );
      expect(result, isEmpty);
    });

    test('excludes recycle-bin entries', () {
      final e = makeEntry(title: 'Trashed', url: 'https://github.com');
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: (_) => true,
        query: const AutofillQuery(domain: 'github.com'),
      );
      expect(result, isEmpty);
      // keep the entry referenced so it isn't optimized away
      expect(e, isNotNull);
    });

    test('empty query returns no candidates', () {
      makeEntry(title: 'A', url: 'https://github.com');
      expect(
        AutofillMatcher.match(
          db.root.allEntries,
          isInRecycleBin: isInRecycleBin,
          query: const AutofillQuery(),
        ),
        isEmpty,
      );
    });

    test('respects the limit parameter', () {
      for (var i = 0; i < 5; i++) {
        makeEntry(title: 'G$i', url: 'https://github.com');
      }
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(domain: 'github.com'),
        limit: 2,
      );
      expect(result, hasLength(2));
    });

    test('candidate subtitle falls back to group path', () {
      final entry = makeEntry(title: 'X', url: 'https://github.com');
      final result = AutofillMatcher.match(
        db.root.allEntries,
        isInRecycleBin: isInRecycleBin,
        query: const AutofillQuery(domain: 'github.com'),
      );
      // entries live directly under root → no intermediate group path →
      // subtitle falls back to the title.
      expect(result.first.subtitle, 'X');
      expect(entry, isNotNull);
    });
  });

  group('AutofillMatchResult.toJson', () {
    test('locked result serializes status and filePath', () {
      final json = const AutofillMatchResult.locked(
        filePath: '/v.kdbx',
      ).toJson();
      expect(json['status'], 'locked');
      expect(json['filePath'], '/v.kdbx');
      expect(json['candidates'], isEmpty);
    });

    test('unlocked result serializes candidates', () {
      final c = AutofillCandidate(
        uuid: 'u',
        title: 't',
        username: 'n',
        password: 'p',
        subtitle: 's',
      );
      final json = AutofillMatchResult.unlocked([c]).toJson();
      expect(json['status'], 'unlocked');
      expect(json['candidates'], hasLength(1));
      expect(json['candidates'].first['uuid'], 'u');
    });
  });
}
