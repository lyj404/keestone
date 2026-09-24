import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/providers/auto_lock_provider.dart';
import 'core/providers/auto_save_provider.dart';
import 'core/providers/expiration_reminder_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/privacy_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/utils/clipboard_utils.dart';
import 'core/utils/logger.dart';
import 'core/utils/window_title_bar.dart';
import 'features/database/providers/database_provider.dart';
import 'features/explorer/providers/explorer_provider.dart';
import 'features/sync/providers/sync_provider.dart';
import 'features/totp/data/totp_service.dart';
import 'l10n/app_localizations.dart';

class KeeStoneApp extends ConsumerStatefulWidget {
  const KeeStoneApp({super.key});

  @override
  ConsumerState<KeeStoneApp> createState() => _KeeStoneAppState();
}

class _KeeStoneAppState extends ConsumerState<KeeStoneApp>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  bool _backgroundPrivacyVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize notifications on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hideInBackground = ref.read(privacyProvider).hideInBackground;
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _backgroundPrivacyVisible = false);
      // WM_DWMCOLORIZATIONCOLORCHANGED can reset the title bar to the OS
      // theme while we are in the background; re-assert the app theme.
      _syncWindowTitleBar(ref.read(themeModeProvider));
      final db = ref.read(databaseProvider).value;
      if (db != null) {
        ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db);
      }
    } else if (hideInBackground &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      if (mounted) setState(() => _backgroundPrivacyVisible = true);
    }
    // Mobile only: the process can be reclaimed at any time after pausing,
    // and dirty data lives only in memory (auto-save is disabled by default).
    // Persist now — the local disk write completes first inside save().
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        !Platform.isWindows &&
        !Platform.isLinux &&
        !Platform.isMacOS) {
      final notifier = ref.read(databaseProvider.notifier);
      if (ref.read(databaseProvider).value != null && notifier.isDirty) {
        unawaited(
          notifier.save().then(
            (_) {},
            onError: (Object e) {
              log.w('Background save failed', error: e);
            },
          ),
        );
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Reset auto-lock timer on any key activity (Bug #1 fix)
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      ref.read(autoLockProvider.notifier).resetTimer();
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (!isCtrl) return KeyEventResult.ignored;

    final navCtx = rootNavigatorKey.currentContext;
    if (navCtx == null) return KeyEventResult.ignored;

    final l10n = AppLocalizations.of(navCtx);

    // Ctrl+F and Ctrl+S are desktop-only shortcuts
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // Ctrl+F: navigate to search
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        GoRouter.of(navCtx).push('/search');
        return KeyEventResult.handled;
      }

      // Ctrl+S: save database
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        _saveDatabase(navCtx, l10n);
        return KeyEventResult.handled;
      }
    }

    // Copy shortcuts require an active entry in an unlocked database.
    final activeEntry = ref.read(activeEntryProvider);
    final dbUnlocked = ref.read(databaseProvider).value != null;
    if (activeEntry == null || !dbUnlocked) return KeyEventResult.ignored;

    String? message;
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      final username = activeEntry.fields['UserName']?.text ?? '';
      if (username.isNotEmpty) {
        copyToClipboardWithAutoClear(username);
        message = l10n!.copiedUsername;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      final password = activeEntry.fields['Password']?.text ?? '';
      if (password.isNotEmpty) {
        copyToClipboardWithAutoClear(password);
        message = l10n!.copiedPassword;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyU) {
      final url = activeEntry.fields['URL']?.text ?? '';
      if (url.isNotEmpty) {
        copyToClipboardWithAutoClear(url);
        message = l10n!.copiedUrl;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyT) {
      final totpCode = _getTotpCode(activeEntry);
      if (totpCode != null) {
        copyToClipboardWithAutoClear(totpCode);
        message = l10n!.copiedTotp;
      }
    }

    if (message != null) {
      ScaffoldMessenger.of(navCtx).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: Theme.of(navCtx).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveDatabase(
    BuildContext navCtx,
    AppLocalizations? l10n,
  ) async {
    final dbState = ref.read(databaseProvider);
    if (!dbState.hasValue || dbState.value == null) return;

    final notifier = ref.read(databaseProvider.notifier);
    final success = await notifier.save();
    if (!navCtx.mounted) return;

    // Local save may succeed while cloud sync reports conflict/error.
    final String message;
    final Color background;
    if (success) {
      message = l10n?.saved ?? 'Saved';
      background = Theme.of(navCtx).colorScheme.primary;
    } else {
      final syncState = ref.read(syncStateProvider);
      if (syncState == SyncState.conflict) {
        message = l10n?.syncConflict ?? 'Sync conflict';
      } else if (syncState == SyncState.error) {
        message = l10n?.syncFailed ?? 'Sync failed';
      } else {
        message = l10n?.saveFailed ?? 'Save failed';
      }
      background = ClayColors.error;
    }
    ScaffoldMessenger.of(navCtx).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String? _getTotpCode(dynamic entry) {
    final config = TotpService().loadFromEntry(entry);
    if (config == null) return null;
    return TotpService().generateCode(config);
  }

  /// Apply the effective theme brightness to the native title bar / chrome.
  void _syncWindowTitleBar(ThemeMode themeMode) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    final Brightness brightness;
    switch (themeMode) {
      case ThemeMode.dark:
        brightness = Brightness.dark;
      case ThemeMode.light:
        brightness = Brightness.light;
      case ThemeMode.system:
        brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
    unawaited(WindowTitleBar.apply(brightness));
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _syncWindowTitleBar(ref.read(themeModeProvider));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final effectiveLocale =
        locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    final themeMode = ref.watch(themeModeProvider);
    final themeSeed = ref.watch(themeSeedProvider);
    final router = ref.watch(appRouterProvider);
    // Auto-save: when the database becomes dirty, arm both the idle deadline
    // and the hard max deadline (user activity only postpones the idle one).
    ref.listen(isDirtyProvider, (prev, next) {
      if (next) {
        ref.read(autoSaveProvider.notifier).onDirty();
      }
    });
    // Keep the native title bar in lockstep with ThemeMode (including the
    // async load from secure storage after first frame).
    _syncWindowTitleBar(themeMode);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          ref.read(autoLockProvider.notifier).resetTimer();
          ref.read(autoSaveProvider.notifier).resetTimer();
        },
        onPointerSignal: (_) {
          ref.read(autoLockProvider.notifier).resetTimer();
          ref.read(autoSaveProvider.notifier).resetTimer();
        },
        child: Stack(
          textDirection: TextDirection.ltr,
          children: [
            MaterialApp.router(
              title: 'KeeStone',
              theme: AppTheme.light(locale: effectiveLocale, seed: themeSeed),
              darkTheme: AppTheme.dark(locale: effectiveLocale, seed: themeSeed),
              themeMode: themeMode,
              routerConfig: router,
              debugShowCheckedModeBanner: false,
              locale: locale,
               localizationsDelegates: [
                 AppLocalizations.delegate,
                 ...GlobalMaterialLocalizations.delegates,
               ],
              supportedLocales: const [Locale('zh'), Locale('en')],
            ),
            if (_backgroundPrivacyVisible)
              Directionality(
                textDirection: TextDirection.ltr,
                child: const ColoredBox(
                  color: ClayColors.surfaceDark,
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
