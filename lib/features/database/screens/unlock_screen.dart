import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/key_file_picker.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/services/biometric_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../backup/data/backup_service.dart';
import '../data/atomic_file_store.dart';
import '../data/database_service.dart';
import '../providers/database_provider.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  final String filePath;
  final bool isCloud;
  final String? webDavProfileId;
  final String? syncedETag;
  const UnlockScreen({
    super.key,
    required this.filePath,
    this.isCloud = false,
    this.webDavProfileId,
    this.syncedETag,
  });

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  Uint8List? _keyData;
  String? _keyFileName;

  bool _biometricTriggered = false;
  bool _lastUnlockUsedBiometric = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget preload: a missing/unreadable file must not surface as
    // an unhandled async exception here — openFile reports it properly.
    unawaited(
      ref.read(databaseProvider.notifier).preloadFile(widget.filePath).catchError(
        (Object e) {
          debugPrint('Preload failed for ${widget.filePath}: $e');
        },
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) {
    final dbState = ref.watch(databaseProvider);
    final bioEnabled = ref.watch(biometricEnabledProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Auto-trigger biometric when provider finishes loading
    if (bioEnabled && !_biometricTriggered) {
      _biometricTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometricUnlock());
    }

    ref.listen(databaseProvider, (prev, next) {
      if (next.isLoading) {
        setState(() => _error = null);
      } else if (next.hasValue) {
        if (next.value != null) {
          // Store credentials only after successful manual unlock.
          if ((Platform.isAndroid || Platform.isIOS) &&
              ref.read(biometricEnabledProvider) &&
              !_lastUnlockUsedBiometric &&
              _passwordController.text.isNotEmpty) {
            BiometricService().storeCredentials(
              widget.filePath,
              _passwordController.text,
              keyData: _keyData,
              keyFileName: _keyFileName,
            );
          }
          context.go('/explorer');
        }
      } else if (next.hasError) {
        final error = next.error!;
        if (error is DatabaseCorruptedException) {
          setState(() => _error = l10n.databaseCorrupted);
          _offerBackupRestore();
        } else {
          setState(() => _error = _friendlyError(error, l10n));
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.unlockDatabase),
        actions: [
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 38,
              height: 38,
              decoration: ClayDecoration.iconContainer(
                brightness: Theme.of(context).brightness,
                radius: 12,
              ),
              child: Icon(
                Icons.settings_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Clay lock icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ClayColors.primary.withValues(alpha: 0.15),
                              ClayColors.tertiary.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: ClayColors.primary.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 34,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _fileName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isCloud ? l10n.cloudDatabase : widget.filePath,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 32),
                      PasswordTextField(
                        controller: _passwordController,
                        labelText: l10n.masterPassword,
                        autofocus: true,
                        validator: (v) => (v == null || v.isEmpty)
                            ? l10n.pleaseEnterPassword
                            : null,
                        onFieldSubmitted: (_) => _unlock(),
                      ),
                      const SizedBox(height: 14),
                      _buildKeyFilePicker(l10n, colorScheme),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: ClayColors.error.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      dbState.isLoading
                          ? Column(
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.decryptingFirstTimeSlow,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: ClayColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton(
                                    onPressed: _unlock,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: Text(l10n.unlock),
                                  ),
                                ),
                                if ((Platform.isAndroid || Platform.isIOS) &&
                                    ref.watch(biometricEnabledProvider)) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _biometricUnlock,
                                    icon: const Icon(
                                      Icons.fingerprint_rounded,
                                      size: 24,
                                    ),
                                    label: Text(l10n.unlockWithBiometric),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _unlock() {
    if (!_formKey.currentState!.validate()) return;
    _lastUnlockUsedBiometric = false;
    setState(() => _error = null);

    // Password will be stored after successful unlock in the ref.listen callback
    ref
        .read(databaseProvider.notifier)
        .openFile(
          widget.filePath,
          _passwordController.text,
          isCloud: widget.isCloud,
          webDavProfileId: widget.webDavProfileId,
          syncedETag: widget.syncedETag,
          keyData: _keyData,
        );
  }

  Future<void> _biometricUnlock() async {
    final l10n = AppLocalizations.of(context)!;
    final biometricService = BiometricService();

    final authenticated = await biometricService.authenticate(
      l10n.authenticateToUnlock,
    );
    if (!authenticated) return;

    final storedCredentials = await biometricService.getStoredCredentials(
      widget.filePath,
    );
    if (storedCredentials == null) {
      // No stored password, need to unlock with password first
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.noStoredPassword)));
      }
      return;
    }

    if (!mounted) return;
    _lastUnlockUsedBiometric = true;
    setState(() {
      _error = null;
      _keyData = storedCredentials.keyData;
      _keyFileName = storedCredentials.keyFileName;
    });
    unawaited(
      ref
          .read(databaseProvider.notifier)
          .openFile(
            widget.filePath,
            storedCredentials.password,
            isCloud: widget.isCloud,
            webDavProfileId: widget.webDavProfileId,
            syncedETag: widget.syncedETag,
            keyData: storedCredentials.keyData,
          ),
    );
  }

  Widget _buildKeyFilePicker(AppLocalizations l10n, ColorScheme colorScheme) {
    return KeyFilePicker(
      keyData: _keyData,
      keyFileName: _keyFileName,
      onKeyDataChanged: (data) => setState(() => _keyData = data),
      onKeyNameChanged: (name) => setState(() => _keyFileName = name),
    );
  }

  String _friendlyError(Object e, AppLocalizations l10n) {
    final msg = e.toString();
    if (msg.contains('InvalidCredentials') || msg.contains('invalid key')) {
      return l10n.passwordError;
    }
    if (msg.contains('corrupt') || msg.contains('bad version')) {
      return l10n.fileFormatIncorrect;
    }
    return l10n.openFailed(msg);
  }

  Future<void> _offerBackupRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final backupService = BackupService();
    final backups = await backupService.listBackupsFor(widget.filePath);
    if (!mounted || backups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.noBackupAvailable)));
      }
      return;
    }

    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreFromBackup),
        content: Text(l10n.restoreFromBackupDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.restoreFromBackup),
          ),
        ],
      ),
    );

    if (restore == true && mounted) {
      try {
        final backupPath = await backupService.getBackupPath(
          backups.first.filename,
        );
        if (backupPath == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.backupNotFound)));
          }
          return;
        }
        final backupBytes = await File(backupPath).readAsBytes();
        // Validate the selected backup with the credentials entered on this
        // screen before replacing the current database.
        await DatabaseService.validateBytes(
          backupBytes,
          _passwordController.text,
          keyData: _keyData,
        );
        await const AtomicFileStore().commit(
          widget.filePath,
          backupBytes,
          backup: () async {
            if (!await File(widget.filePath).exists()) return;
            final currentBackup = await backupService.createBackup(
              widget.filePath,
            );
            if (currentBackup == null) {
              throw const FileSystemException(
                'Unable to back up current database',
              );
            }
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
          // Re-trigger unlock with the restored file
          _unlock();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.backupRestoreFailed)));
        }
      }
    }
  }
}
