import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/key_file_picker.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/database_provider.dart';

class CreateDatabaseScreen extends ConsumerStatefulWidget {
  const CreateDatabaseScreen({super.key});

  @override
  ConsumerState<CreateDatabaseScreen> createState() => _CreateDatabaseScreenState();
}

class _CreateDatabaseScreenState extends ConsumerState<CreateDatabaseScreen> {
  late TextEditingController _nameController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _savePath;
  bool _initialized = false;
  Uint8List? _keyData;
  String? _keyFileName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _nameController = TextEditingController(text: AppLocalizations.of(context)!.myDatabase);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbState = ref.watch(databaseProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    ref.listen(databaseProvider, (prev, next) {
      next.whenOrNull(
        data: (db) {
          if (db != null) context.go('/explorer');
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createDatabase)),
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
                      // Clay icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.15),
                              colorScheme.secondary.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(Icons.add_rounded, size: 34, color: colorScheme.primary),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.databaseName,
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterName : null,
                      ),
                      const SizedBox(height: 14),
                      PasswordTextField(
                        controller: _passwordController,
                        labelText: l10n.masterPassword,
                        showStrengthIndicator: true,
                        validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterPassword : null,
                      ),
                      const SizedBox(height: 14),
                      PasswordTextField(
                        controller: _confirmController,
                        labelText: l10n.confirmPassword,
                        validator: (v) => v != _passwordController.text ? l10n.passwordsNotMatch : null,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _pickSaveLocation,
                        icon: Icon(_savePath != null ? Icons.check_circle_outline_rounded : Icons.save_as_rounded, size: 18),
                        label: Text(
                          _savePath == null
                              ? l10n.selectSaveLocation
                              : _savePath!.split('/').last.split('\\').last,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: _savePath != null ? colorScheme.primary : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildKeyFilePicker(l10n, colorScheme),
                      const SizedBox(height: 24),
                      dbState.isLoading
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.primary),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: FilledButton(
                                onPressed: _savePath != null ? _create : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: Text(l10n.create),
                              ),
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

  Future<void> _pickSaveLocation() async {
    final l10n = AppLocalizations.of(context)!;
    // Android/iOS FilePicker.saveFile requires `bytes` up front, so we cannot
    // only pick a path before the KDBX exists. Use app documents instead.
    if (Platform.isAndroid || Platform.isIOS) {
      final path = await _defaultMobileSavePath();
      if (!mounted) return;
      setState(() => _savePath = path);
      showToast(context, path.split('/').last);
      return;
    }
    final result = await FilePicker.platform.saveFile(
      dialogTitle: l10n.saveDatabase,
      fileName: '${_nameController.text}${AppConstants.kdbxExtension}',
      type: FileType.custom,
      allowedExtensions: ['kdbx'],
    );
    if (result != null) {
      setState(() => _savePath = result);
    }
  }

  Future<String> _defaultMobileSavePath() async {
    final dir = await getApplicationDocumentsDirectory();
    var name = _nameController.text.trim();
    if (name.isEmpty) name = 'database';
    // Keep the leaf name filesystem-safe on Android/iOS.
    name = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    return '${dir.path}/$name${AppConstants.kdbxExtension}';
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || _savePath == null) return;
    var savePath = _savePath!;
    if (Platform.isAndroid || Platform.isIOS) {
      // Recompute so a later rename of the database still lands on a valid path.
      savePath = await _defaultMobileSavePath();
      if (mounted) setState(() => _savePath = savePath);
    }
    await ref.read(databaseProvider.notifier).createDatabase(
          _nameController.text,
          _passwordController.text,
          savePath,
          keyData: _keyData,
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
}
