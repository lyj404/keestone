part of 'settings_screen.dart';

// These methods are extensions on State so the database settings stay grouped.
// ignore_for_file: invalid_use_of_protected_member

extension _SettingsDatabaseCards on _SettingsScreenState {
  List<Widget> _databaseCards() {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    return [
      _changePasswordCard(brightness, l10n),
      _passwordHealthCard(brightness, l10n),
      _backupCard(brightness, l10n),
    ];
  }

  Widget _passwordHealthCard(Brightness brightness, AppLocalizations l10n) {
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
              Icons.health_and_safety_outlined,
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
                  l10n.passwordHealth,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  l10n.passwordHealthSubtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                onTap: () => context.push('/audit'),
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
    // The Git backend form does not use this confirmation.
    if (_syncMode == 'git') return true;
    final config = WebDavConfig(
      id: _selectedProfileId ?? 'tmp',
      name: _profileNameController.text.trim(),
      serverUrl: _urlController.text.trim(),
    );
    bool insecure;
    try {
      insecure = config.usesInsecureHttp;
    } on FormatException {
      return false;
    }
    if (!insecure) return true;
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.webDavInsecureHttpTitle),
            content: Text(l10n.webDavInsecureHttpBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: ButtonLabel(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: ButtonLabel(l10n.confirm),
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
      if (errorKey != null && errorKey.startsWith('path_not_accessible:')) {
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
            child: ButtonLabel(l10n.reenterPath),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_PathNotExistChoice.create),
            child: ButtonLabel(l10n.createPath),
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
      if (_enabled) {
        // The sync backends are mutually exclusive: enabling WebDAV disables
        // Git and S3 so no entry point can ever pick the wrong one.
        await _disableGitProfiles();
        await _disableAllS3Profiles();
      }
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
            child: ButtonLabel(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: ButtonLabel(l10n.delete),
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
}
