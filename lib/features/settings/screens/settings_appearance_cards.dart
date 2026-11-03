part of 'settings_screen.dart';

extension _SettingsAppearanceCards on _SettingsScreenState {
  // --- Appearance --------------------------------------------------------

  List<Widget> _appearanceCards(WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _themeCard(Theme.of(context).brightness, l10n, ref),
      _themeSeedCard(Theme.of(context).brightness, l10n, ref),
    ];
  }

  Widget _themeSeedCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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
                decoration: ClayDecoration.iconContainer(
                  brightness: brightness,
                ),
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

  Widget _themeCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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
            focusColor: ClayDecoration.dropdownFocusColor,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text(l10n.followSystem),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text(l10n.lightTheme),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text(l10n.darkTheme),
              ),
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

  List<Widget> _securityCards(WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    return [
      _autoLockCard(brightness, l10n, ref),
      _privacyCard(brightness, l10n, ref),
      if ((Platform.isAndroid || Platform.isIOS) &&
          ref.watch(biometricAvailableProvider).value == true)
        _unlockMethodCard(brightness, l10n, ref),
    ];
  }

  Widget _autoLockCard(
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
            focusColor: ClayDecoration.dropdownFocusColor,
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

  Widget _privacyCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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

  Widget _unlockMethodCard(
    Brightness brightness,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
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
                decoration: ClayDecoration.iconContainer(
                  brightness: brightness,
                ),
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
                selected:
                    ref.watch(unlockMethodProvider) == UnlockMethod.password,
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
}
