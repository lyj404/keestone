import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/crypto/crypto_service.dart';
import 'core/providers/global_container.dart';
import 'core/utils/clipboard_utils.dart';
import 'core/utils/legacy_migration.dart';
import 'core/utils/logger.dart';
import 'core/utils/secure_store.dart';
import 'core/providers/close_behavior_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/tray_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/theme_seed.dart';
import 'core/theme/theme_seed_icons.dart';
import 'l10n/app_localizations.dart';
import 'features/database/providers/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initSecureStoreBackend();
  await LegacyMigration.run();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(900, 680),
      minimumSize: Size(400, 300),
      center: true,
      title: 'KeeStone',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true);
    });
  }

  // Capture the root ProviderContainer globally so headless background handlers
  // can read providers without a BuildContext. UncontrolledProviderScope exposes
  // an externally-owned container; it lives for the whole process and is
  // intentionally not disposed (no shorter owner than the app itself).
  globalContainer = ProviderContainer();

  runApp(
    UncontrolledProviderScope(
      container: globalContainer,
      child: const KeeStoneAppWrapper(),
    ),
  );
}

class KeeStoneAppWrapper extends ConsumerStatefulWidget {
  const KeeStoneAppWrapper({super.key});

  @override
  ConsumerState<KeeStoneAppWrapper> createState() => _KeeStoneAppWrapperState();
}

class _KeeStoneAppWrapperState extends ConsumerState<KeeStoneAppWrapper>
    with WindowListener {
  bool _trayInitialized = false;
  bool _closing = false;
  bool _quitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(fileLogOutput.init());
      CryptoService.initialize();
    });
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _initTray();
        if (!mounted) return;
        // Seed may have loaded after first frame; apply current seed.
        await _applySeedIcons(ref.read(themeSeedProvider));
      });
    }
  }

  Future<void> _initTray() async {
    final navContext = rootNavigatorKey.currentContext;
    final l10n = navContext != null ? AppLocalizations.of(navContext) : null;
    try {
      await TrayService().init(
        showLabel: l10n?.showMainWindow ?? 'Show Main Window',
        exitLabel: l10n?.exit ?? 'Exit',
        onShowWindow: _showWindow,
        onExitApp: _exitApp,
      );
      _trayInitialized = true;
    } catch (e) {
      log.w('Tray init failed, close will exit app', error: e);
      _trayInitialized = false;
    }
  }

  /// Keep tray + window titlebar icons in sync with the active theme seed.
  Future<void> _applySeedIcons(ThemeSeed seed) async {
    await TrayService().setSeedIcon(seed);
    if (Platform.isWindows || Platform.isLinux) {
      try {
        await windowManager.setIcon(ThemeSeedIcons.assetPath(seed));
      } catch (e) {
        log.w('windowManager.setIcon failed', error: e);
      }
    }
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _persistDirtyDatabase() async {
    final db = ref.read(databaseProvider).valueOrNull;
    if (db == null) return;
    final notifier = ref.read(databaseProvider.notifier);

    try {
      // Local disk write happens first inside save(); the timeout mainly
      // bounds slow cloud sync retries so app exit isn't blocked for ~45s.
      // A save already in flight may have serialized before the latest edit,
      // so keep saving until the dirty flag clears (bounded) before exiting.
      for (var attempt = 0; attempt < 3 && notifier.isDirty; attempt++) {
        final success =
            await notifier.save().timeout(const Duration(seconds: 20));
        if (!success) {
          log.w(
            'Database save before app exit completed locally, but cloud sync reported a conflict.',
          );
          break;
        }
      }
    } on TimeoutException {
      log.w('Save before app exit timed out; local save may have completed.');
    } catch (e, st) {
      log.e(
        'Failed to save database before app exit',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _terminateApp() async {
    _quitting = true;
    try {
      await _persistDirtyDatabase();
      await clearClipboardIfCopied();
      try {
        await TrayService().dispose();
      } catch (_) {}
      try {
        NotificationService().dispose();
      } catch (_) {}
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {}
  }

  Future<void> _exitApp() async {
    await _terminateApp();
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // The close event can fire again while the (async) handling below is in
    // progress; without a guard the dialog and exit sequence would run twice.
    if (_closing) return;
    _closing = true;
    try {
      // The preference loads asynchronously; never act on the default before
      // it has been read (a fast close on startup would otherwise ignore the
      // user's remembered choice).
      await ref.read(closeBehaviorProvider.notifier).ensureLoaded();
      final behavior = ref.read(closeBehaviorProvider);
      if (behavior == CloseBehavior.exit) {
        await _exitApp();
        return;
      }
      if (behavior == CloseBehavior.minimizeToTray) {
        if (_trayInitialized) {
          await windowManager.hide();
        } else {
          await _exitApp();
        }
        return;
      }
      await _showCloseDialog();
    } finally {
      // Exit paths run once; minimize paths leave the app running, so close
      // handling must be re-enabled for the next window-close event.
      if (!_quitting) _closing = false;
    }
  }

  Future<void> _showCloseDialog() async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      await windowManager.hide();
      return;
    }
    final l10n = AppLocalizations.of(navContext);
    bool remember = false;

    final result = await showDialog<bool>(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bodyStyle = theme.textTheme.bodyMedium;
        final labelStyle = theme.textTheme.labelLarge;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                l10n?.close ?? 'Close',
                style: theme.textTheme.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.closeWindowMessage ?? 'What would you like to do?',
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(
                            l10n?.minimize ?? 'Minimize',
                            style: labelStyle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(l10n?.exit ?? 'Exit', style: labelStyle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: remember,
                        onChanged: (v) =>
                            setDialogState(() => remember = v ?? false),
                      ),
                      Flexible(
                        child: Text(
                          l10n?.rememberChoice ?? 'Remember my choice',
                          style: bodyStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      if (remember) {
        await ref
            .read(closeBehaviorProvider.notifier)
            .setCloseBehavior(CloseBehavior.exit);
      }
      await _terminateApp();
    } else {
      if (remember) {
        await ref
            .read(closeBehaviorProvider.notifier)
            .setCloseBehavior(CloseBehavior.minimizeToTray);
      }
      if (_trayInitialized) {
        await windowManager.hide();
      } else {
        await _terminateApp();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ref.listen<ThemeSeed>(themeSeedProvider, (previous, next) {
        if (previous == next) return;
        unawaited(_applySeedIcons(next));
      });
    }
    return const KeeStoneApp();
  }
}
