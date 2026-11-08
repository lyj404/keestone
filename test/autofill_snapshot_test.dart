import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/features/autofill/data/autofill_credential_snapshot.dart';

void main() {
  group('AutofillSnapshotEntry', () {
    test('round-trips through JSON', () {
      final e = AutofillSnapshotEntry(
        uuid: 'u',
        title: 't',
        username: 'user',
        password: 'pw',
        domains: const ['example.com'],
        packageIds: const ['com.example.app'],
      );
      final json = e.toJson();
      final back = AutofillSnapshotEntry.fromJson(
        Map<String, dynamic>.from(json),
      );
      expect(back.uuid, 'u');
      expect(back.title, 't');
      expect(back.username, 'user');
      expect(back.password, 'pw');
      expect(back.domains, ['example.com']);
      expect(back.packageIds, ['com.example.app']);
    });
  });

  group('AutofillSnapshot', () {
    test('round-trips through JSON with version and entries', () {
      final s = AutofillSnapshot(
        createdAt: 1234,
        entries: [
          AutofillSnapshotEntry(
            uuid: 'a',
            title: 'A',
            username: '',
            password: 'p',
            domains: const ['a.com'],
            packageIds: const [],
          ),
        ],
      );
      final jsonStr = s.toUtf8JsonString();
      final back = AutofillSnapshot.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      expect(back.version, AutofillSnapshot.currentVersion);
      expect(back.createdAt, 1234);
      expect(back.entries, hasLength(1));
      expect(back.entries.first.uuid, 'a');
      expect(back.entries.first.domains, ['a.com']);
    });
  });

  group('AutofillSnapshotFile wrap/unwrap', () {
    test('round-trips arbitrary combined bytes', () {
      final combined = Uint8List.fromList(List<int>.generate(40, (i) => i));
      final wrapped = AutofillSnapshotFile.wrap(combined);
      expect(wrapped[0], 0x4B); // 'K'
      expect(wrapped[3], 0x46); // 'F'
      expect(wrapped[4], 1); // format version
      final unwrapped = AutofillSnapshotFile.unwrap(wrapped);
      expect(unwrapped, equals(combined));
    });

    test('returns null for bad magic', () {
      final bytes = Uint8List.fromList([0, 0, 0, 0, 1, ...List<int>.filled(28, 0)]);
      expect(AutofillSnapshotFile.unwrap(bytes), isNull);
    });

    test('returns null for unknown format version', () {
      final bytes = Uint8List.fromList([
        0x4B, 0x56, 0x41, 0x46, 9, ...List<int>.filled(28, 0),
      ]);
      expect(AutofillSnapshotFile.unwrap(bytes), isNull);
    });

    test('returns null for too-short input', () {
      expect(AutofillSnapshotFile.unwrap(Uint8List(4)), isNull);
    });
  });

  group('AES-GCM round-trip with CryptoKit-compatible layout', () {
    test('encrypt -> combined -> decrypt recovers the JSON snapshot', () async {
      final s = AutofillSnapshot(
        createdAt: 1,
        entries: [
          AutofillSnapshotEntry(
            uuid: 'u',
            title: 't',
            username: 'n',
            password: 'p',
            domains: const ['host.com'],
            packageIds: const [],
          ),
        ],
      );
      final clearText = Uint8List.fromList(
        utf8.encode(s.toUtf8JsonString()),
      );
      final cipher = AesGcm.with256bits();
      final key = await cipher.newSecretKey();
      final box = await cipher.encrypt(clearText, secretKey: key);
      // CryptoKit expects: nonce(12) || ciphertext || tag(16)
      final combined = Uint8List.fromList(box.concatenation());
      expect(combined.length, 12 + clearText.length + 16);

      // Decrypt back using fromConcatenation (mirrors CryptoKit's split).
      final restored = SecretBox.fromConcatenation(
        combined,
        nonceLength: cipher.nonceLength,
        macLength: cipher.macAlgorithm.macLength,
      );
      final plain = await cipher.decrypt(restored, secretKey: key);
      expect(Uint8List.fromList(plain), equals(clearText));
      expect(
        jsonDecode(utf8.decode(plain)),
        jsonDecode(s.toUtf8JsonString()),
      );
    });
  });
}
