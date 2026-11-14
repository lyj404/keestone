import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keestone/core/theme/theme_seed.dart';
import 'package:keestone/core/tray_service.dart';

Future<String> _dbus(List<String> arguments) async {
  final result = await Process.run('gdbus', [
    'call',
    '--session',
    ...arguments,
  ]);
  if (result.exitCode != 0) {
    throw StateError('gdbus failed: ${result.stderr}');
  }
  return result.stdout as String;
}

Future<String> _waitForService() async {
  final pattern = RegExp('org\\.kde\\.StatusNotifierItem-$pid-\\d+');
  for (var i = 0; i < 50; i++) {
    final names = await _call(
      'org.kde.StatusNotifierWatcher',
      '/StatusNotifierWatcher',
      'org.freedesktop.DBus.Properties.Get',
      ['org.kde.StatusNotifierWatcher', 'RegisteredStatusNotifierItems'],
    );
    final match = pattern.firstMatch(names);
    if (match != null) return match.group(0)!;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Tray service did not register with D-Bus');
}

Future<String> _call(
  String service,
  String path,
  String method, [
  List<String> arguments = const [],
]) => _dbus([
  '--dest',
  service,
  '--object-path',
  path,
  '--method',
  method,
  '--',
  ...arguments,
]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux tray exports its icon and handles menu actions', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final tray = TrayService();
      final shown = Completer<void>();
      final exited = Completer<void>();
      try {
        await tray.init(
          showLabel: 'Show test window',
          exitLabel: 'Exit test app',
          onShowWindow: shown.complete,
          onExitApp: exited.complete,
        );
        final service = await _waitForService();
        final properties = await _call(
          service,
          '/StatusNotifierItem',
          'org.freedesktop.DBus.Properties.Get',
          ['org.kde.StatusNotifierItem', 'Menu'],
        );
        expect(properties, contains('/StatusNotifierItem/Menu'));

        final iconBefore = await _call(
          service,
          '/StatusNotifierItem',
          'org.freedesktop.DBus.Properties.Get',
          ['org.kde.StatusNotifierItem', 'IconPixmap'],
        );
        expect(iconBefore, isNot(contains('<[]>')));
        await tray.setSeedIcon(ThemeSeed.sky);
        final iconAfter = await _call(
          service,
          '/StatusNotifierItem',
          'org.freedesktop.DBus.Properties.Get',
          ['org.kde.StatusNotifierItem', 'IconPixmap'],
        );
        expect(iconAfter, isNot(equals(iconBefore)));

        final layout = await _call(
          service,
          '/StatusNotifierItem/Menu',
          'com.canonical.dbusmenu.GetLayout',
          ['0', '-1', '[]'],
        );
        int itemId(String label) {
          final pattern = RegExp("\\((\\d+), \\{[^}]*'label': <'$label'>");
          final match = pattern.firstMatch(layout);
          if (match == null) throw StateError('Menu item missing: $label');
          return int.parse(match.group(1)!);
        }

        Future<void> click(String label) async {
          await _call(
            service,
            '/StatusNotifierItem/Menu',
            'com.canonical.dbusmenu.Event',
            ['${itemId(label)}', 'clicked', '<0>', '0'],
          );
        }

        await click('Show test window');
        await shown.future.timeout(const Duration(seconds: 5));
        await click('Exit test app');
        await exited.future.timeout(const Duration(seconds: 5));
      } finally {
        await tray.dispose();
      }
    });
  }, skip: !Platform.isLinux);
}
