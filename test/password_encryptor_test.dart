import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/utils/password_encryptor.dart';
import 'package:keestone/core/utils/secure_store.dart';

class _MemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PasswordEncryptor', () {
    late _MemorySecureStore store;
    late PasswordEncryptor encryptor;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = _MemorySecureStore();
      encryptor = PasswordEncryptor(store);
    });

    test('encrypts to ENC2 and round-trips', () async {
      final encrypted = await encryptor.encrypt('hunter2');
      expect(encrypted, startsWith('ENC2:'));
      expect(encrypted, isNot(contains('hunter2')));
      expect(await encryptor.decrypt(encrypted), 'hunter2');
    });

    test('rejects tampered ciphertext', () async {
      final encrypted = await encryptor.encrypt('hunter2');
      final body = encrypted.substring('ENC2:'.length);
      final flipped = body.replaceFirst(body[10], body[10] == 'A' ? 'B' : 'A');
      await expectLater(
        encryptor.decrypt('ENC2:$flipped'),
        throwsA(isA<PasswordDecryptionException>()),
      );
    });

    test(
      'decrypting without the original key never creates a replacement',
      () async {
        final ciphertext = await encryptor.encrypt('secret');
        final missingKeyStore = _MemorySecureStore();
        final other = PasswordEncryptor(missingKeyStore);
        await expectLater(
          other.decrypt(ciphertext),
          throwsA(isA<PasswordDecryptionException>()),
        );
        expect(missingKeyStore.values, isEmpty);
      },
    );

    test('authenticates old macOS key before recovering credentials', () async {
      final oldStore = _MemorySecureStore();
      final ciphertext = await PasswordEncryptor(oldStore).encrypt('secret');
      final newStore = _MemorySecureStore();
      await PasswordEncryptor(newStore).encrypt('new secret');
      final newKey = newStore.values['webdav_enc_key'];
      final oldKey = oldStore.values['webdav_enc_key'];
      final migrated = PasswordEncryptor(
        MacOSMigratingSecureStore(newStore, oldStore),
      );
      expect(await migrated.decrypt(ciphertext), 'secret');
      expect(newStore.values['webdav_enc_key'], newKey);
      expect(oldStore.values['webdav_enc_key'], oldKey);
    });

    test('returns plaintext as-is and encrypts it on demand', () async {
      expect(await encryptor.decrypt('plain-secret'), 'plain-secret');
      final upgraded = await encryptor.encrypt('plain-secret');
      expect(upgraded, startsWith('ENC2:'));
      expect(await encryptor.decrypt(upgraded), 'plain-secret');
    });
  });
}
