import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/button_label.dart';
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
import '../../../core/services/log_export_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../autofill/providers/autofill_provider.dart';
import '../../autofill/services/autofill_control.dart';
import '../../autotype/providers/autotype_provider.dart';
import '../../autotype/services/autotype_native.dart';
import '../providers/username_suggest_provider.dart';
import '../../sync/data/git_config.dart';
import '../data/webdav_config.dart';
import '../providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';

part 'settings_appearance_cards.dart';
part 'settings_sync_cards.dart';
part 'settings_database_cards.dart';
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
  // Git sync form controllers.
  final _gitRepoController = TextEditingController();
  final _gitTokenController = TextEditingController();
  final _gitFileController = TextEditingController(text: 'database.kdbx');

  /// Gist/snippet id of the loaded profile, shown read-only after the first
  /// sync creates the remote store.
  String? _gitGistId;
  List<WebDavConfig> _profiles = const [];
  String? _selectedProfileId;
  String? _selectedGitProfileId;
  String _gitProvider = 'github';

  /// Which sync backend the sync cards currently edit.
  String _syncMode = 'webdav'; // 'webdav' | 'git'
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
    final gitProfiles = await ref
        .read(gitSettingsServiceProvider)
        .getProfiles();
    if (!mounted) return;
    // Default the backend switch to whichever sync backend is actually
    // enabled; re-entering settings must not reset an explicit choice.
    final gitEnabled = gitProfiles.any((p) => p.enabled);
    setState(() {
      _profiles = state.profiles;
      _selectedProfileId = state.activeProfile?.id;
      _applyConfigToForm(state.activeProfile);
      _selectedGitProfileId = gitProfiles.isEmpty ? null : gitProfiles.first.id;
      _applyGitConfigToForm(gitProfiles.isEmpty ? null : gitProfiles.first);
      _syncMode = gitEnabled ? 'git' : 'webdav';
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
    _gitRepoController.dispose();
    _gitTokenController.dispose();
    _gitFileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Desktop: category sidebar + detail panes. Mobile: single column.
    if (ClayLayout.isWide(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? ClayColors.surfaceDark
            : ClayColors.surfaceLight,
        appBar: AppBar(title: Text(l10n.settings)),
        body: _SettingsWideLayout(
          categories: [
            _SettingsCategorySpec(
              icon: Icons.tune_rounded,
              label: l10n.settingsCategoryGeneral,
              content: Consumer(
                builder: (context, cardsRef, _) =>
                    _pane(context, _generalCards(cardsRef)),
              ),
            ),
            _SettingsCategorySpec(
              icon: Icons.palette_outlined,
              label: l10n.settingsCategoryAppearance,
              content: Consumer(
                builder: (context, cardsRef, _) =>
                    _pane(context, _appearanceCards(cardsRef)),
              ),
            ),
            _SettingsCategorySpec(
              icon: Icons.shield_outlined,
              label: l10n.settingsCategorySecurity,
              content: Consumer(
                builder: (context, cardsRef, _) =>
                    _pane(context, _securityCards(cardsRef)),
              ),
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
      _categoryCards(_generalCards),
      const SizedBox(height: 16),
      _categoryCards(_appearanceCards),
      const SizedBox(height: 16),
      _categoryCards(_securityCards),
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

  /// Rebuild boundary for one settings category: provider watches inside the
  /// card builders attach to this Consumer instead of the screen's build, so
  /// toggling one setting no longer rebuilds every category.
  Widget _categoryCards(List<Widget> Function(WidgetRef ref) buildCards) =>
      Consumer(
        builder: (context, ref, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _withGaps(buildCards(ref)),
        ),
      );

  // --- General -----------------------------------------------------------

  List<Widget> _generalCards(WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    return [
      _languageCard(brightness, l10n, ref),
      _autoSaveCard(brightness, l10n, ref),
      _usernameSuggestCard(brightness, l10n, ref),
      _expirationReminderCard(brightness, l10n, ref),
      if (Platform.isAndroid || Platform.isIOS)
        _autofillCard(brightness, l10n, ref),
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
        _autotypeCard(brightness, l10n, ref),
      if (Platform.isMacOS || Platform.isAndroid)
        _logExportCard(brightness, l10n),
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
        _closeBehaviorCard(brightness, l10n, ref),
    ];
  }

  Widget _languageCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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
            focusColor: ClayDecoration.dropdownFocusColor,
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

  Widget _autoSaveCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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
            focusColor: ClayDecoration.dropdownFocusColor,
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

  Widget _usernameSuggestCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = ref.watch(usernameSuggestProvider);
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.person_search_rounded,
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
                  l10n.usernameSuggestTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  l10n.usernameSuggestSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (v) =>
                ref.read(usernameSuggestProvider.notifier).setEnabled(v),
          ),
        ],
      ),
    );
  }

  Widget _expirationReminderCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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
            focusColor: ClayDecoration.dropdownFocusColor,
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

  Widget _autotypeCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = ref.watch(autoTypeStatusProvider);
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
                  Icons.keyboard_rounded,
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
                      l10n.autotypeSettingsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.autotypeSettingsSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: status.enabled,
                onChanged: autotypeSessionUnsupported
                    ? null
                    : (v) async {
                  final service = ref.read(autoTypeServiceProvider);
                  await service.setEnabled(v);
                  final registered =
                      v && autotypePlatformSupported
                          ? await AutoTypeNative.isHotkeyRegistered()
                          : false;
                  ref.read(autoTypeStatusProvider.notifier).state =
                      service.status.copyWith(
                    hotkeyRegistered: registered,
                  );
                  if (v && mounted) {
                    showToast(
                      context,
                      registered
                          ? l10n.autotypeHotkeyOk
                          : l10n.autotypeHotkeyFail,
                      isError: !registered,
                    );
                  }
                },
              ),
            ],
          ),
          if (status.enabled && status.hotkeyRegistered) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.autotypeHotkeyOk,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (autotypeSessionUnsupported) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.autotypeWaylandDisabled,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _autofillCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = ref.watch(autofillEnabledProvider);
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
                  Icons.password_rounded,
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
                      l10n.autofill,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.autofillDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: (v) => ref
                    .read(autofillEnabledProvider.notifier)
                    .setEnabled(v),
              ),
            ],
          ),
          if (enabled) ...[
            if (Platform.isAndroid)
              _AutofillDefaultStatusTile(l10n: l10n)
            else if (Platform.isIOS)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.autofillIosHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _closeBehaviorCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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
            focusColor: ClayDecoration.dropdownFocusColor,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: CloseBehavior.ask,
                child: Text(l10n.askEveryTime),
              ),
              DropdownMenuItem(
                value: CloseBehavior.minimizeToTray,
                child: Text(l10n.minimizeToTray),
              ),
              DropdownMenuItem(
                value: CloseBehavior.exit,
                child: Text(l10n.exitApp),
              ),
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

  Widget _logExportCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(
              Icons.ios_share_rounded,
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
                  l10n.exportLogs,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  l10n.exportLogsDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _exportLogs,
            child: ButtonLabel(l10n.exportLogs),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogs() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final exported = await LogExportService.export();
      if (!mounted) return;
      showToast(context, exported ? l10n.exportSuccess : l10n.noLogsToExport);
    } catch (e) {
      log.w('Export logs failed', error: e);
      if (mounted) {
        showToast(context, l10n.exportFailed, isError: true);
      }
    }
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

class _AutofillDefaultStatusTile extends StatefulWidget {
  final AppLocalizations l10n;

  const _AutofillDefaultStatusTile({required this.l10n});

  @override
  State<_AutofillDefaultStatusTile> createState() =>
      _AutofillDefaultStatusTileState();
}

class _AutofillDefaultStatusTileState extends State<_AutofillDefaultStatusTile> {
  bool? _isDefault; // null = unknown / not checked yet

  @override
  void initState() {
    super.initState();
    _refreshDefault();
  }

  Future<void> _refreshDefault() async {
    final value = await AutofillControl.isDefaultService();
    if (mounted) setState(() => _isDefault = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = widget.l10n;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        _isDefault == true
            ? Icons.check_circle_rounded
            : Icons.info_outline_rounded,
        size: 20,
        color: _isDefault == true ? colorScheme.primary : null,
      ),
      title: Text(
        _isDefault == true ? l10n.autofillIsDefault : l10n.autofillNotDefault,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: _isDefault == true
          ? null
          : TextButton(
              onPressed: () async {
                await AutofillControl.requestSetDefault();
                // The system prompt is async; re-check after a beat.
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted) await _refreshDefault();
              },
              child: Text(l10n.setAsAutofillService),
            ),
    );
  }
}
