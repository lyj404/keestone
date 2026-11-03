part of 'settings_screen.dart';

// These methods are extensions on State so sync settings stay grouped here.
// ignore_for_file: invalid_use_of_protected_member

extension _SettingsSyncCards on _SettingsScreenState {
  // --- Sync (WebDAV) -----------------------------------------------------

  List<Widget> _syncCards() {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final cards = <Widget>[
      _syncModeCard(brightness, l10n),
      if (_syncMode == 'webdav') ...[
        _webdavToggleCard(brightness, l10n),
        if (_enabled) ...[
          _webdavConfigCard(brightness, l10n),
          ..._webdavActions(l10n),
        ],
      ] else ...[
        _gitConfigCard(brightness, l10n),
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

  /// Backend switch shown above the sync forms.
  Widget _syncModeCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Column(
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
                      l10n.syncBackend,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.autoSyncOnSave,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'webdav',
                label: ButtonLabel(l10n.syncBackendWebdav),
                icon: const Icon(Icons.dns_rounded, size: 18),
              ),
              ButtonSegment(
                value: 'git',
                label: ButtonLabel(l10n.syncBackendGit),
                icon: const Icon(Icons.merge_rounded, size: 18),
              ),
            ],
            selected: {_syncMode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() {
                _syncMode = selection.first;
                _connectionOk = null;
                _connectionError = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // --- Git sync ----------------------------------------------------------

  Widget _gitConfigCard(Brightness brightness, AppLocalizations l10n) {
    return _SectionCard(
      brightness: brightness,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _gitProvider,
            decoration: InputDecoration(labelText: l10n.gitProvider),
            items: [
              for (final p in GitSyncConfig.supportedProviders)
                DropdownMenuItem<String>(
                  value: p,
                  child: Text(switch (p) {
                    'github' => 'GitHub',
                    'gitee' => 'Gitee (码云)',
                    _ => 'GitLab',
                  }),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _gitProvider = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _gitRepoController,
            decoration: InputDecoration(
              labelText: l10n.gitRepoUrl,
              helperText: l10n.gitSiteUrlHelper,
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              // GitHub/Gitee have fixed API bases, so the site URL is
              // optional there; a self-hosted GitLab must provide its host.
              if (value.isEmpty) {
                if (_gitProvider == 'gitlab') {
                  return l10n.pleaseEnterServerAddress;
                }
                return null;
              }
              if (GitSyncConfig(
                    id: 'validation',
                    name: 'validation',
                    provider: _gitProvider,
                    repoUrl: value,
                  ).parsedRepo ==
                  null) {
                return l10n.webDavInvalidUrl;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (_gitGistId != null && _gitGistId!.isNotEmpty)
            TextFormField(
              initialValue: _gitGistId,
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.gitGistId,
                helperText: l10n.gitGistIdHelper,
              ),
            ),
          if (_gitGistId != null && _gitGistId!.isNotEmpty)
            const SizedBox(height: 12),
          PasswordTextField(
            controller: _gitTokenController,
            labelText: l10n.gitToken,
            showPrefixIcon: false,
            validator: (v) =>
                (v == null || v.isEmpty) ? l10n.pleaseEnterPassword : null,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gitTokenHelper,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _gitFileController,
            decoration: InputDecoration(
              labelText: l10n.filename,
              hintText: 'database.kdbx',
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? l10n.pleaseEnterName : null,
          ),
          const SizedBox(height: 12),
          // Save button for the Git profile (independent of the WebDAV one).
          FilledButton.icon(
            onPressed: _saveGit,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: ButtonLabel(l10n.save),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  GitSyncConfig _gitConfigFromForm({bool enabled = true}) => GitSyncConfig(
    id: _selectedGitProfileId ?? _generateGitProfileId(),
    name: 'Git',
    provider: _gitProvider,
    repoUrl: _gitRepoController.text.trim(),
    gistId: _gitGistId ?? '',
    token: _gitTokenController.text,
    remoteFilename: _gitFileController.text.trim(),
    enabled: enabled,
  );

  /// Persists the form, merging it into the stored profile instead of
  /// replacing it: the gistId (and anything else the form does not edit)
  /// survives, so saving settings can never orphan an existing snippet.
  Future<void> _saveGit() async {
    log.i('[GitSync] Save button clicked');
    try {
      if (!_formKey.currentState!.validate()) return;
      final profileId = _selectedGitProfileId ?? _generateGitProfileId();
      final existing = await ref
          .read(gitSettingsServiceProvider)
          .getConfigById(profileId);
      final config = _gitConfigFromForm(enabled: existing?.enabled ?? true)
          .copyWith(
            id: profileId,
            // The form has no gistId field; keep the stored one.
            gistId: existing?.gistId ?? '',
          );
      await ref.read(gitSettingsServiceProvider).saveConfig(config);
      if (config.enabled) {
        // The two sync backends are mutually exclusive: enabling Git
        // disables WebDAV so no entry point can ever pick the wrong one.
        await _disableAllWebDavProfiles();
      }
      if (!mounted) return;
      await _loadConfig();
      if (!mounted) return;
      _selectedGitProfileId = profileId;
      setState(() {
        _connectionOk = null;
        _connectionError = null;
      });
      final l10n = AppLocalizations.of(context)!;
      showToast(context, l10n.saved);
    } catch (e, st) {
      log.e('[GitSync] Save failed', error: e, stackTrace: st);
      if (mounted) {
        showToast(context, e.toString(), isError: true);
      }
    }
  }

  void _applyGitConfigToForm(GitSyncConfig? config) {
    if (config == null) {
      _gitProvider = 'github';
      _gitRepoController.text = '';
      _gitGistId = null;
      _gitTokenController.text = '';
      _gitFileController.text = 'database.kdbx';
      return;
    }
    _gitProvider = GitSyncConfig.supportedProviders.contains(config.provider)
        ? config.provider
        : 'github';
    _gitRepoController.text = config.repoUrl;
    _gitGistId = config.gistId;
    _gitTokenController.text = config.token;
    _gitFileController.text = config.remoteFilename;
  }

  /// Disables every WebDAV profile. Used to enforce the mutual exclusion of
  /// the two sync backends when a Git profile is enabled.
  Future<void> _disableAllWebDavProfiles() async {
    final service = ref.read(webDavSettingsServiceProvider);
    final state = await service.getProfilesState();
    for (final profile in state.profiles) {
      if (!profile.enabled) continue;
      await service.saveConfig(profile.copyWith(enabled: false));
    }
  }

  /// Disables every Git profile. Used to enforce the mutual exclusion of the
  /// two sync backends when WebDAV is enabled.
  Future<void> _disableGitProfiles() async {
    final service = ref.read(gitSettingsServiceProvider);
    for (final profile in await service.getProfiles()) {
      if (!profile.enabled) continue;
      await service.saveConfig(profile.copyWith(enabled: false));
    }
  }

  String _generateGitProfileId() {
    return 'git_${DateTime.now().microsecondsSinceEpoch}';
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
                decoration: ClayDecoration.iconContainer(
                  brightness: brightness,
                ),
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
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.pleaseEnterName : null,
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
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
            validator: (v) =>
                (v == null || v.isEmpty) ? l10n.pleaseEnterName : null,
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
              label: ButtonLabel(_testing ? l10n.testing : l10n.testConnection),
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
                    color: _connectionOk!
                        ? ClayColors.secondary
                        : ClayColors.error,
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
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.3),
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
          child: ButtonLabel(l10n.save),
        ),
      ),
    ];
  }

  // --- Database ----------------------------------------------------------
}
