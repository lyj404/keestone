import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('compare macOS Keychain modes', (tester) async {
    expect(Platform.isMacOS, isTrue);
    const regular = FlutterSecureStorage();
    const legacy = FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    );
    final suffix = DateTime.now().microsecondsSinceEpoch;

    Future<void> check(FlutterSecureStorage storage, String key) async {
      await storage.write(key: key, value: 'keestone-ci-test');
      expect(await storage.read(key: key), 'keestone-ci-test');
      await storage.delete(key: key);
      expect(await storage.read(key: key), isNull);
    }

    // Default mode is diagnostic: failure is expected on affected builds.
    try {
      await check(regular, 'keestone_ci_default_$suffix');
      // ignore: avoid_print
      print('Default Keychain: read/write/delete succeeded');
    } catch (error) {
      // ignore: avoid_print
      print('Default Keychain failed: $error');
    }
    await check(legacy, 'keestone_ci_legacy_$suffix');
  });
}
