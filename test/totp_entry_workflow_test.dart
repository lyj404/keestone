import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/core/router/app_router.dart';
import 'package:keestone/core/utils/clipboard_utils.dart';
import 'package:keestone/features/database/data/database_service.dart';
import 'package:keestone/features/database/providers/database_provider.dart';
import 'package:keestone/features/settings/providers/settings_provider.dart';
import 'package:keestone/features/totp/data/totp_service.dart';
import 'package:keestone/features/totp/widgets/totp_display_widget.dart';
import 'package:keestone/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class _OpenDatabaseNotifier extends DatabaseNotifier {
  _OpenDatabaseNotifier(super.ref, KdbxDatabase database) {
    state = AsyncData(database);
  }
}

void main() {
  const seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  const otpUri = 'otpauth://totp/Fixture?secret=$seed&period=86400&digits=8';
  late Directory directory;
  late DatabaseService service;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('keestone_totp_');
    file = File('${directory.path}/fixture.kdbx');
    service = DatabaseService();
    await service.createDatabase('Fixture', 'test-password', file.path);
    final root = service.db!.root;
    final group = service.createGroup(root, 'Accounts');
    final external = service.createEntry(group);
    external.fields['Title'] = KdbxTextField.fromText(text: 'External account');
    external.fields['otp'] = KdbxTextField.fromText(
      text: otpUri,
      protected: true,
    );
    final legacy = service.createEntry(root);
    legacy.fields['Title'] = KdbxTextField.fromText(text: 'Seed account');
    legacy.fields['TOTP Seed'] = KdbxTextField.fromText(
      text: seed,
      protected: true,
    );
    legacy.fields['TOTP Settings'] = KdbxTextField.fromText(text: '30;6');
    final standard = service.createEntry(root);
    standard.fields['Title'] = KdbxTextField.fromText(text: 'Standard account');
    TotpService().saveToEntry(standard, const TotpConfig(secret: seed));
    final deleted = service.createEntry(root);
    deleted.fields['Title'] = KdbxTextField.fromText(text: 'Deleted account');
    deleted.fields['otp'] = KdbxTextField.fromText(text: otpUri);
    service.deleteItem(deleted);
    await file.writeAsBytes(await service.saveToBytes());
    service.close();
    await service.openFile(file.path, 'test-password');
  });

  tearDown(() async {
    service.onDirtyChanged = null;
    service.close();
    await directory.delete(recursive: true);
  });

  testWidgets('shows imported TOTP, preserves ordinary edits and removes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        databaseServiceProvider.overrideWithValue(service),
        databaseProvider.overrideWith(
          (ref) => _OpenDatabaseNotifier(ref, service.db!),
        ),
        webDavConfigProvider.overrideWith((_) async => null),
      ],
    );
    addTearDown(container.dispose);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
    final router = container.read(appRouterProvider)..go('/explorer');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'TOTP'));
    await tester.pumpAndSettle();
    expect(find.text('Seed account'), findsOneWidget);
    expect(find.text('Standard account'), findsOneWidget);
    expect(find.text('Deleted account'), findsNothing);
    final code = find.textContaining(RegExp(r'^\d{8}$'));
    final listCode = tester.widget<Text>(code).data;

    await tester.tap(find.text('External account'));
    await tester.pumpAndSettle();
    expect(find.text(listCode!), findsOneWidget);
    final copy = find.descendant(
      of: find.byType(TotpDisplayWidget),
      matching: find.byTooltip('Copy'),
    );
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(clipboard, listCode);
    await clearClipboardIfCopied();

    final entry = service.findGroupByPath('Accounts')!.entries.single;
    final field = entry.fields['otp'];
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Renamed account');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(listCode), findsOneWidget);
    expect(entry.fields['otp'], same(field));
    expect(entry.fields['otp'], isA<ProtectedTextField>());
    final reopened = await tester.runAsync(() async {
      await file.writeAsBytes(await service.saveToBytes());
      final reader = DatabaseService();
      try {
        await reader.openFile(file.path, 'test-password');
        return reader.findGroupByPath('Accounts')!.entries.single.fields['otp'];
      } finally {
        reader.close();
      }
    });
    expect(reopened, isA<ProtectedTextField>());
    expect(reopened!.text, otpUri);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    final remove = find.byTooltip('Delete TOTP');
    await tester.scrollUntilVisible(
      remove,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final editTotp = find.widgetWithText(TextButton, 'Edit');
    await tester.ensureVisible(editTotp);
    await tester.pumpAndSettle();
    await tester.tap(editTotp);
    await tester.pumpAndSettle();
    expect(find.text('86400s'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(listCode), findsNothing);
    expect(entry.fields['otp'], isNull);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Renamed account'), findsNothing);
    expect(find.text('Seed account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
