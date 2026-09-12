import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/change_password_dialog.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/theme_seed.dart';
import '../../../core/providers/auto_lock_provider.dart';
import '../../../core/providers/auto_save_provider.dart';
import '../../../core/providers/privacy_provider.dart';
import '../../../core/providers/close_behavior_provider.dart';
import '../../../core/providers/expiration_reminder_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/services/biometric_service.dart';
import '../../../l10n/app_localizations.dart';
import '../data/webdav_config.dart';
import '../providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';

part 'settings_layouts.dart';

/// User's choice when prompted that the remote path does not exist.
enum _PathNotExistChoice { reenter, create }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileNameController = TextEditingController();
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController();
  final _filenameController = TextEditingController(text: 'database.kdbx');
  List<WebDavConfig> _profiles = const [];
  String? _selectedProfileId;
  bool _enabled = false;
  bool _testing = false;
  bool? _connectionOk;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final state = await ref
        .read(webDavSettingsServiceProvider)
        .getProfilesState();
    if (!mounted) return;
    setState(() {
      _profiles = state.profiles;
      _selectedProfileId = state.activeProfile?.id;
      _applyConfigToForm(state.activeProfile);
      _connectionOk = null;
      _connectionError = null;
    });
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _urlController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Desktop: category sidebar + detail panes. Mobile: single column.
    if (ClayLayout.isWide(context)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settings)),
        body: _SettingsWideLayout(
          categories: [
            _SettingsCategorySpec(
              icon: Icons.tune_rounded,
              label: l10n.settingsCategoryGeneral,
              content: _pane(context, _generalCards()),
            ),
            _SettingsCategorySpec(
              icon: Icons.palette_outlined,
              label: l10n.settingsCategoryAppearance,
              content: _pane(context, _appearanceCards()),
            ),
            _SettingsCategorySpec(
              icon: Icons.shield_outlined,
              label: l10n.settingsCategorySecurity,
              content: _pane(context, _securityCards()),
            ),
            _SettingsCategorySpec(
              icon: Icons.cloud_upload_rounded,
              label: l10n.settingsCategorySync,
              content: _pane(context, _syncCards()),
            ),
            _SettingsCategorySpec(
              icon: Icons.storage_rounded,
              label: l10n.settingsCategoryDatabase,
              content: _pane(context, _databaseCards()),
            ),
          ],
        ),
      );
    }

    final children = [
      ..._withGaps(_generalCards()),
      const SizedBox(height: 16),
      ..._withGaps(_appearanceCards()),
      const SizedBox(height: 16),
      ..._withGaps(_securityCards()),
      const SizedBox(height: 16),
      // _syncCards() already wraps its content in Form(_formKey).
      ..._withGaps(_syncCards()),
      const SizedBox(height: 16),
      ..._withGaps(_databaseCards()),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  /// Detail pane for the desktop layout: independently scrollable, content
  /// centered at a readable measure.
  Widget _pane(BuildContext context, List<Widget> cards) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withGaps(cards),
          ),
        ),
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> cards) => [
    for (var i = 0; i < cards.length; i++) ...[
      if (i > 0) const SizedBox(height: 16),
      cards[i],
    ],
  ];

  // --- General -----------------------------------------------------------

  List<Widget> _generalCards() {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    return [
      _languageCard(brightness, l10n),
      _autoSaveCard(brightness, l10n),
      _expirationReminderCard(brightness, l10n),
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
        _closeBehaviorCard(brightness, l10n),
    ];
  }

  Widget _languageCard(Brightness brightness, AppLocalizations l10n) {
    final currentLocale = ref.watch(localeProvider);
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.language_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.language,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: currentLocale?.languageCode ?? 'system',
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 'system', child: Text(l10n.followSystem)),
              const DropdownMenuItem(value: 'zh', child: Text('中文')),
              const DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == 'system') {
                ref.read(localeProvider.notifier).setLocale(null);
              } else {
                ref.read(localeProvider.notifier).setLocale(Locale(v));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _autoSaveCard(Brightness brightness, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Icon(Icons.save_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.autoSave,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  l10n.autoSaveDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: ref.watch(autoSaveProvider),
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 0, child: Text(l10n.disabled)),
              DropdownMenuItem(value: 15, child: Text('15 ${l10n.seconds}')),
              DropdownMenuItem(value: 30, child: Text('30 ${l10n.seconds}')),
              DropdownMenuItem(value: 60, child: Text('60 ${l10n.seconds}')),
              DropdownMenuItem(value: 120, child: Text('120 ${l10n.seconds}')),
              DropdownMenuItem(value: 300, child: Text('300 ${l10n.seconds}')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(autoSaveProvider.notifier).setSeconds(v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _expirationReminderCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.notifications_active_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.expirationReminder,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  l10n.expirationReminderDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: ref.watch(expirationReminderProvider),
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 0, child: Text(l10n.disabled)),
              DropdownMenuItem(
                value: 1,
                child: Text('1 ${l10n.daysBeforeExpiry}'),
              ),
              DropdownMenuItem(
                value: 3,
                child: Text('3 ${l10n.daysBeforeExpiry}'),
              ),
              DropdownMenuItem(
                value: 7,
                child: Text('7 ${l10n.daysBeforeExpiry}'),
              ),
              DropdownMenuItem(
                value: 14,
                child: Text('14 ${l10n.daysBeforeExpiry}'),
              ),
              DropdownMenuItem(
                value: 30,
                child: Text('30 ${l10n.daysBeforeExpiry}'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(expirationReminderProvider.notifier).setDays(v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _closeBehaviorCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.closeBehavior,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          DropdownButton<CloseBehavior>(
            value: ref.watch(closeBehaviorProvider),
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: CloseBehavior.ask, child: Text(l10n.askEveryTime)),
              DropdownMenuItem(
                value: CloseBehavior.minimizeToTray,
                child: Text(l10n.minimizeToTray),
              ),
              DropdownMenuItem(value: CloseBehavior.exit, child: Text(l10n.exitApp)),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(closeBehaviorProvider.notifier).setCloseBehavior(v);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Appearance --------------------------------------------------------

  List<Widget> _appearanceCards() {
    final l10n = AppLocalizations.of(context)!;
    return [
      _themeCard(Theme.of(context).brightness, l10n),
      _themeSeedCard(Theme.of(context).brightness, l10n),
    ];
  }

  Widget _themeSeedCard(Brightness brightness, AppLocalizations l10n) {
    final currentSeed = ref.watch(themeSeedProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return _SectionCard(
      brightness: brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: ClayDecoration.iconContainer(brightness: brightness),
                child: Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.colorScheme,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final seed in ThemeSeed.values)
                _ThemeSeedSwatch(
                  seed: seed,
                  selected: seed == currentSeed,
                  onTap: () =>
                      ref.read(themeSeedProvider.notifier).setThemeSeed(seed),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeCard(Brightness brightness, AppLocalizations l10n) {
    final currentThemeMode = ref.watch(themeModeProvider);
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              currentThemeMode == ThemeMode.dark
                  ? Icons.dark_mode_rounded
                  : currentThemeMode == ThemeMode.light
                  ? Icons.light_mode_rounded
                  : Icons.brightness_auto_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.theme,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          DropdownButton<ThemeMode>(
            value: currentThemeMode,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.followSystem)),
              DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.lightTheme)),
              DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.darkTheme)),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(v);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Security ----------------------------------------------------------

  List<Widget> _securityCards() {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    return [
      _autoLockCard(brightness, l10n),
      _privacyCard(brightness, l10n),
      if ((Platform.isAndroid || Platform.isIOS) &&
          ref.watch(biometricAvailableProvider).valueOrNull == true)
        _unlockMethodCard(brightness, l10n),
    ];
  }

  Widget _autoLockCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.lock_clock_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.autoLock,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  l10n.autoLockDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: ref.watch(autoLockProvider),
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 0, child: Text(l10n.disabled)),
              DropdownMenuItem(value: 1, child: Text('1 ${l10n.minute}')),
              DropdownMenuItem(value: 5, child: Text('5 ${l10n.minutes}')),
              DropdownMenuItem(value: 15, child: Text('15 ${l10n.minutes}')),
              DropdownMenuItem(value: 30, child: Text('30 ${l10n.minutes}')),
              DropdownMenuItem(value: 60, child: Text('60 ${l10n.minutes}')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(autoLockProvider.notifier).setMinutes(v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _privacyCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.privacyProtection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.blockScreenshots),
            subtitle: Text(l10n.blockScreenshotsDescription),
            value: ref.watch(privacyProvider).blockScreenshots,
            onChanged: (value) =>
                ref.read(privacyProvider.notifier).setBlockScreenshots(value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.hideInBackground),
            subtitle: Text(l10n.hideInBackgroundDescription),
            value: ref.watch(privacyProvider).hideInBackground,
            onChanged: (value) =>
                ref.read(privacyProvider.notifier).setHideInBackground(value),
          ),
        ],
      ),
    );
  }

  Widget _unlockMethodCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: ClayDecoration.iconContainer(brightness: brightness),
                child: Icon(
                  Icons.lock_open_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.unlockMethod,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _UnlockMethodChip(
                icon: Icons.password_rounded,
                label: l10n.unlockByPassword,
                selected: ref.watch(unlockMethodProvider) == UnlockMethod.password,
                onTap: () => _setUnlockMethod(UnlockMethod.password, l10n),
              ),
              const SizedBox(width: 10),
              _UnlockMethodChip(
                icon: Icons.fingerprint_rounded,
                label: l10n.unlockByBiometric,
                selected:
                    ref.watch(unlockMethodProvider) == UnlockMethod.biometric,
                onTap: () => _setUnlockMethod(UnlockMethod.biometric, l10n),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Sync (WebDAV) -----------------------------------------------------

  List<Widget> _syncCards() {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final cards = <Widget>[
      _webdavToggleCard(brightness, l10n),
      if (_enabled) ...[
        _webdavConfigCard(brightness, l10n),
        ..._webdavActions(l10n),
      ],
    ];
    return [
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _withGaps(cards),
        ),
      ),
    ];
  }

  Widget _webdavToggleCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: ClayDecoration.iconContainer(brightness: brightness),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.webdavSync,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.autoSyncOnSave,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedProfileId,
                  decoration: InputDecoration(
                    labelText: l10n.webdavProfile,
                    border: const OutlineInputBorder(),
                  ),
                  items: _profiles
                      .map(
                        (profile) => DropdownMenuItem<String>(
                          value: profile.id,
                          child: Text(profile.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _selectProfile(value);
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _createNewProfile,
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: l10n.newProfile,
              ),
              IconButton(
                onPressed: _profiles.length <= 1 ? null : _deleteCurrentProfile,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: l10n.delete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _webdavConfigCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Column(
        children: [
          TextFormField(
            controller: _profileNameController,
            decoration: InputDecoration(labelText: l10n.profileName),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.pleaseEnterName
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: l10n.serverAddress,
              hintText: l10n.serverAddressHint,
              helperText: l10n.serverAddressHelper,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.pleaseEnterServerAddress;
              }
              final uri = Uri.tryParse(v.trim());
              if (uri == null ||
                  !uri.hasAuthority ||
                  (uri.scheme != 'http' && uri.scheme != 'https')) {
                return l10n.webDavInvalidUrl;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userController,
            decoration: InputDecoration(labelText: l10n.username),
            validator: (v) =>
                (v == null || v.isEmpty) ? l10n.pleaseEnterUsername : null,
          ),
          const SizedBox(height: 12),
          PasswordTextField(
            controller: _passwordController,
            labelText: l10n.password,
            showPrefixIcon: false,
            validator: (v) =>
                (v == null || v.isEmpty) ? l10n.pleaseEnterPassword : null,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appPasswordHelper,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pathController,
            decoration: InputDecoration(
              labelText: l10n.remotePathOptional,
              hintText: l10n.remotePathHint,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _filenameController,
            decoration: InputDecoration(
              labelText: l10n.filename,
              hintText: 'database.kdbx',
            ),
            validator: (v) => (v == null || v.isEmpty)
                ? l10n.pleaseEnterName
                : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _webdavActions(AppLocalizations l10n) {
    return [
      // Test connection
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find_rounded, size: 18),
              label: Text(_testing ? l10n.testing : l10n.testConnection),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
                ),
              ),
            ),
          ),
        ],
      ),
      if (_connectionOk != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _connectionOk!
                ? ClayColors.secondary.withValues(alpha: 0.1)
                : ClayColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _connectionOk!
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                size: 18,
                color: _connectionOk! ? ClayColors.secondary : ClayColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _connectionOk!
                      ? l10n.connectionSuccess
                      : (_connectionError ?? l10n.connectionFailed),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _connectionOk! ? ClayColors.secondary : ClayColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      // Save button
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(l10n.save),
        ),
      ),
    ];
  }

  // --- Database ----------------------------------------------------------

  List<Widget> _databaseCards() {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    return [_changePasswordCard(brightness, l10n), _backupCard(brightness, l10n)];
  }

  Widget _changePasswordCard(Brightness brightness, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.key_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.changeMasterPassword,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showChangePasswordDialog(context),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupCard(Brightness brightness, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.backup_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.databaseBackup,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push('/backup'),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmInsecureHttp() async {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri?.scheme != 'http') return true;
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.webDavInsecureHttpTitle),
            content: Text(l10n.webDavInsecureHttpBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmInsecureHttp() || !mounted) return;
    setState(() {
      _testing = true;
      _connectionOk = null;
      _connectionError = null;
    });
    try {
      final config = WebDavConfig(
        id: _selectedProfileId ?? _generateProfileId(),
        name: _profileNameController.text.trim(),
        serverUrl: _urlController.text.trim(),
        username: _userController.text.trim(),
        password: _passwordController.text,
        remotePath: _pathController.text.trim(),
        remoteFilename: _filenameController.text.trim(),
      );
      final errorKey = await ref
          .read(syncServiceProvider)
          .testConnection(config);
      if (!mounted) return;

      // Path missing on an otherwise reachable server: ask the user whether
      // to re-enter the path or create it now. We intercept before showing an
      // error so the dialog drives the next action.
      if (errorKey != null &&
          errorKey.startsWith('path_not_accessible:')) {
        final path = errorKey.substring('path_not_accessible:'.length);
        final choice = await _promptPathNotExist(path);
        if (!mounted) return;
        if (choice == _PathNotExistChoice.create) {
          await _createRemotePath(config);
        }
        // For re-enter or dismiss: leave the form as-is so the user can edit.
        return;
      }

      setState(() {
        _testing = false;
        _connectionOk = errorKey == null;
        _connectionError = _translateError(errorKey);
      });
    } catch (e, st) {
      log.e('WebDAV test connection failed', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _testing = false;
          _connectionOk = false;
          _connectionError = e.toString();
        });
      }
    }
  }

  String? _translateError(String? errorKey) {
    if (errorKey == null) return null;
    final l10n = AppLocalizations.of(context)!;
    if (errorKey == 'auth_failed') return l10n.authFailedCheckCredentials;
    if (errorKey == 'network_failed') return l10n.networkFailedCheckServer;
    if (errorKey.startsWith('path_not_accessible:')) {
      final path = errorKey.substring('path_not_accessible:'.length);
      return l10n.serverConnectedPathNotAccessible(path);
    }
    if (errorKey.startsWith('connection_failed:')) {
      final msg = errorKey.substring('connection_failed:'.length);
      return l10n.connectionFailedMsg(msg);
    }
    return errorKey;
  }

  Future<_PathNotExistChoice?> _promptPathNotExist(String path) async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<_PathNotExistChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pathNotExistTitle),
        content: Text(l10n.pathNotExistMessage(path)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PathNotExistChoice.reenter),
            child: Text(l10n.reenterPath),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PathNotExistChoice.create),
            child: Text(l10n.createPath),
          ),
        ],
      ),
    );
  }

  Future<void> _createRemotePath(WebDavConfig config) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _testing = true;
      _connectionOk = null;
      _connectionError = null;
    });
    try {
      await ref.read(syncServiceProvider).ensureRemoteDirectory(config);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _connectionOk = true;
        _connectionError = l10n.pathCreated;
      });
    } catch (e, st) {
      log.e('WebDAV create path failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _connectionOk = false;
        _connectionError = l10n.pathCreateFailed(e.toString());
      });
    }
  }

  Future<void> _save() async {
    log.i('[WebDAV] Save button clicked');
    try {
      if (!_formKey.currentState!.validate()) {
        log.w('[WebDAV] Save stopped: form validation failed');
        return;
      }
      if (!await _confirmInsecureHttp() || !mounted) {
        log.i('[WebDAV] Save cancelled before writing');
        return;
      }
      final profileId = _selectedProfileId ?? _generateProfileId();
      final config = WebDavConfig(
        id: profileId,
        name: _profileNameController.text.trim(),
        serverUrl: _urlController.text.trim(),
        username: _userController.text.trim(),
        password: _passwordController.text,
        remotePath: _pathController.text.trim(),
        remoteFilename: _filenameController.text.trim(),
        enabled: _enabled,
      );
      await ref.read(webDavSettingsServiceProvider).saveConfig(config);
      await ref.read(webDavSettingsServiceProvider).setActiveProfile(profileId);
      _selectedProfileId = profileId;
      await _loadConfig();
      ref.invalidate(webDavConfigProvider);
      ref.invalidate(webDavProfilesStateProvider);
      if (!mounted) return;
      log.i('[WebDAV] Save completed, profiles=${_profiles.length}');
      if (_profiles.isEmpty) {
        log.e(
          'WebDAV profiles empty after save — secure storage may be '
          'unavailable on this platform',
        );
        final l10n = AppLocalizations.of(context)!;
        showToast(context, l10n.webdavSaveFailedStorage, isError: true);
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      showToast(context, l10n.saved);
      context.pop();
    } catch (e, st) {
      log.e('[WebDAV] Save failed', error: e, stackTrace: st);
      if (mounted) {
        showToast(context, e.toString(), isError: true);
      }
    }
  }

  void _applyConfigToForm(WebDavConfig? config) {
    if (config == null) {
      _profileNameController.text = '';
      _urlController.text = '';
      _userController.text = '';
      _passwordController.text = '';
      _pathController.text = '';
      _filenameController.text = 'database.kdbx';
      _enabled = false;
      return;
    }
    _profileNameController.text = config.name;
    _urlController.text = config.serverUrl;
    _userController.text = config.username;
    _passwordController.text = config.password;
    _pathController.text = config.remotePath;
    _filenameController.text = config.remoteFilename;
    _enabled = config.enabled;
  }

  Future<void> _selectProfile(String profileId) async {
    try {
      final service = ref.read(webDavSettingsServiceProvider);
      await service.setActiveProfile(profileId);
      final config = await service.getConfigById(profileId);
      if (!mounted) return;
      setState(() {
        _selectedProfileId = profileId;
        _applyConfigToForm(config);
        _connectionOk = null;
        _connectionError = null;
      });
      ref.invalidate(webDavConfigProvider);
      ref.invalidate(webDavProfilesStateProvider);
    } catch (e, st) {
      log.e('Failed to select profile', error: e, stackTrace: st);
      if (mounted) {
        showToast(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _createNewProfile() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final index = _profiles.length + 1;
      final profile = WebDavConfig(
        id: _generateProfileId(),
        name: '${l10n.profile} $index',
        serverUrl: '',
        username: '',
        password: '',
      );
      await ref.read(webDavSettingsServiceProvider).saveConfig(profile);
      await _loadConfig();
      ref.invalidate(webDavConfigProvider);
      ref.invalidate(webDavProfilesStateProvider);
    } catch (e, st) {
      log.e('Failed to create profile', error: e, stackTrace: st);
      if (mounted) {
        showToast(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _deleteCurrentProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final profile = _profiles
        .where((p) => p.id == _selectedProfileId)
        .firstOrNull;
    if (profile == null) return;
    if (_profiles.length <= 1) {
      showToast(context, l10n.cannotDeleteLastProfile, isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteProfileConfirm(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(webDavSettingsServiceProvider).deleteProfile(profile.id);
      await _loadConfig();
      ref.invalidate(webDavConfigProvider);
      ref.invalidate(webDavProfilesStateProvider);
    } catch (e, st) {
      log.e('Failed to delete profile', error: e, stackTrace: st);
      if (mounted) {
        showToast(context, e.toString(), isError: true);
      }
    }
  }

  String _generateProfileId() {
    return 'webdav_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _setUnlockMethod(
    UnlockMethod method,
    AppLocalizations l10n,
  ) async {
    if (method == UnlockMethod.biometric) {
      final biometricService = BiometricService();
      final authenticated = await biometricService.authenticate(
        l10n.authenticateToEnableBiometric,
      );
      if (!authenticated) {
        if (mounted) {
          showToast(context, l10n.biometricAuthFailed, isError: true);
        }
        return;
      }
    } else {
      final biometricService = BiometricService();
      await biometricService.clearAllStoredPasswords();
    }
    await ref.read(unlockMethodProvider.notifier).setMethod(method);
    if (mounted) {
      showToast(
        context,
        method == UnlockMethod.biometric
            ? l10n.biometricEnabled
            : l10n.biometricDisabled,
      );
    }
  }
}

class _UnlockMethodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnlockMethodChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Brightness brightness;
  final Widget child;

  const _SectionCard({required this.brightness, required this.child});

  @override
  Widget build(BuildContext context) {
    return SectionCard(children: [child]);
  }
}
