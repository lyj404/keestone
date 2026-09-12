import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import 'password_text_field.dart';
import 'toast.dart';
import '../../l10n/app_localizations.dart';
import '../../features/database/providers/database_provider.dart';

/// Shows a dialog to change the master password of the currently open database.
Future<void> showChangePasswordDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;

  // Key file state
  late bool _hasExistingKeyFile;
  Uint8List? _newKeyData;
  String? _newKeyFileName;
  bool _removeKeyFile = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _hasExistingKeyFile = ref.read(databaseProvider.notifier).hasKeyFile;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(Icons.key_rounded, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Text(l10n.changeMasterPassword),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordTextField(
                controller: _oldPasswordCtrl,
                labelText: l10n.currentPassword,
                autofocus: true,
                validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterCurrentPassword : null,
              ),
              const SizedBox(height: 14),
              PasswordTextField(
                controller: _newPasswordCtrl,
                labelText: l10n.newPassword,
                showStrengthIndicator: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.pleaseEnterNewPassword;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              PasswordTextField(
                controller: _confirmCtrl,
                labelText: l10n.confirmNewPassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.pleaseEnterPassword;
                  if (v != _newPasswordCtrl.text) return l10n.passwordsNotMatch;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildKeyFileSection(l10n, colorScheme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.confirm),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;

    // Determine if we need to update the key file
    bool updateKeyFile = false;
    Uint8List? keyData;

    if (_hasExistingKeyFile) {
      // Database already has a key file
      if (_removeKeyFile) {
        updateKeyFile = true;
        keyData = null;
      } else if (_newKeyData != null) {
        updateKeyFile = true;
        keyData = _newKeyData;
      }
      // else: keep existing key file, don't update
    } else {
      // Database doesn't have a key file
      if (_newKeyData != null) {
        updateKeyFile = true;
        keyData = _newKeyData;
      }
    }

    try {
      await ref.read(databaseProvider.notifier).changePassword(
        _oldPasswordCtrl.text,
        _newPasswordCtrl.text,
        updateKeyFile: updateKeyFile,
        newKeyData: keyData,
      );
      if (mounted) {
        showToast(context, l10n.passwordChanged);
        Navigator.pop(context);
      }
    } on InvalidCredentialsError {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, l10n.passwordError, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, l10n.error(e.toString()), isError: true);
      }
    }
  }

  Widget _buildKeyFileSection(AppLocalizations l10n, ColorScheme colorScheme) {
    // Show new key file if selected
    if (_newKeyData != null) {
      return _buildNewKeyFileChip(l10n, colorScheme);
    }

    // Show existing key file if present and not removing
    if (_hasExistingKeyFile && !_removeKeyFile) {
      return _buildExistingKeyFileChip(l10n, colorScheme);
    }

    // Show add button
    return _buildAddKeyFileButton(l10n, colorScheme);
  }

  Widget _buildExistingKeyFileChip(AppLocalizations l10n, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.keyFileSelected,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _pickNewKeyFile,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.changeKeyFile),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => setState(() => _removeKeyFile = true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colorScheme.error,
            ),
            child: Text(l10n.removeKeyFile),
          ),
        ],
      ),
    );
  }

  Widget _buildNewKeyFileChip(AppLocalizations l10n, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _newKeyFileName ?? l10n.keyFileSelected,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: colorScheme.onSurfaceVariant),
            onPressed: () => setState(() {
              _newKeyData = null;
              _newKeyFileName = null;
            }),
            tooltip: l10n.removeKeyFile,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildAddKeyFileButton(AppLocalizations l10n, ColorScheme colorScheme) {
    return OutlinedButton.icon(
      onPressed: _pickNewKeyFile,
      icon: const Icon(Icons.vpn_key_rounded, size: 18),
      label: Text(l10n.selectKeyFile),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _pickNewKeyFile() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _newKeyData = bytes;
        _newKeyFileName = file.name;
        _removeKeyFile = false;
      });
    }
  }
}
