import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/utils/secure_store.dart';

class MemoryStore implements SecureStore {
  final values = <String, String>{};
  Object? failure;
  void check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<String?> read({required String key}) async {
    check();
    return values[key];
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    check();
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    check();
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    check();
    return Map.of(values);
  }
}

void main() {
  late MemoryStore current;
  late MemoryStore previous;
  late MacOSMigratingSecureStore store;
  setUp(() {
    current = MemoryStore();
    previous = MemoryStore();
    store = MacOSMigratingSecureStore(current, previous);
  });

  test('migrates old value and preserves current value', () async {
    previous.values['key'] = 'old';
    expect(await store.read(key: 'key'), 'old');
    expect(current.values['key'], 'old');
    expect(previous.values, isEmpty);
    previous.values['key'] = 'stale';
    expect(await store.read(key: 'key'), 'old');
    await store.delete(key: 'key');
    expect(await store.read(key: 'key'), isNull);
  });

  test(
    'missing entitlement allows current store but other errors propagate',
    () async {
    previous.failure = PlatformException(
      code: 'Unexpected security result code',
      details: -34018,
    );
      await store.write(key: 'key', value: 'value');
      expect(await store.read(key: 'key'), 'value');
      expect(await store.read(key: 'missing'), isNull);
      previous.failure = StateError('unavailable');
      expect(() => store.read(key: 'missing'), throwsStateError);
    },
  );

  test(
    'readAll migrates missing entries without replacing current entries',
    () async {
      previous.values.addAll({'a': 'old', 'b': 'migrate'});
      current.values['a'] = 'new';
      expect(await store.readAll(), {'a': 'new', 'b': 'migrate'});
      expect(previous.values, isEmpty);
    },
  );
}
