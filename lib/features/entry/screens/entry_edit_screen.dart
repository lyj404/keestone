import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auto_lock_provider.dart';
import '../../../core/providers/auto_save_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/attachments_section.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/password_generator_dialog.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/button_label.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';
import '../../totp/data/totp_service.dart';
import '../../totp/widgets/totp_edit_sheet.dart';

part 'entry_edit_sections.dart';

class EntryEditScreen extends ConsumerStatefulWidget {
  final String? entryUuid;
  final String groupPath;

  const EntryEditScreen({super.key, this.entryUuid, required this.groupPath});

  @override
  ConsumerState<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _CustomFieldData {
  String originalKey;
  final TextEditingController nameCtrl;
  final TextEditingController valueCtrl;
  final FocusNode nameFocus;
  bool protected;
  bool obscure;

  _CustomFieldData({
    required this.originalKey,
    required String name,
    required String value,
    this.protected = false,
  }) : nameCtrl = TextEditingController(text: name),
       valueCtrl = TextEditingController(text: value),
       nameFocus = FocusNode(),
       obscure = protected;

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
    nameFocus.dispose();
  }
}

class _EntryEditScreenState extends ConsumerState<EntryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_CustomFieldData> _customFields = [];
  final List<String> _tags = [];
  bool _isEdit = false;
  KdbxEntry? _entry;
  bool _wasDirtyBeforeCreate = false;
  KdbxGroup? _targetGroup;
  bool _loaded = false;
  bool _expires = false;
  DateTime? _expiryDate;
  TotpConfig? _totpConfig;
  final _totpService = TotpService();

  @override
  void initState() {
    super.initState();
    // Defer _loadEntry() to didChangeDependencies (Bug #8 fix)
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadEntry();
      // Attach activity listeners only after the initial values are loaded so
      // programmatic field population is not treated as a user edit.
      _titleCtrl.addListener(_onFormChanged);
      _usernameCtrl.addListener(_onFormChanged);
      _passwordCtrl.addListener(_onFormChanged);
      _urlCtrl.addListener(_onFormChanged);
      _notesCtrl.addListener(_onFormChanged);
    }
  }

  /// Any edit on this screen counts as user activity: reset the auto-lock and
  /// auto-save timers so typing (which produces no pointer/key events at the
  /// root listener on mobile) cannot trigger a mid-edit lock, and remember
  /// there are unsaved changes for the back-navigation guard.
  void _onFormChanged() {
    _hasChanges = true;
    ref.read(autoLockProvider.notifier).resetTimer();
    ref.read(autoSaveProvider.notifier).resetTimer();
  }

  Future<void> _confirmDiscardChanges() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: ButtonLabel(l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: ButtonLabel(l10n.discardAndLeave),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      context.pop();
    }
  }

  void _loadEntry() {
    final service = ref.read(databaseServiceProvider);

    // Look up by UUID if provided
    if (widget.entryUuid != null && widget.entryUuid!.isNotEmpty) {
      final uuid = KdbxUuid.fromString(widget.entryUuid!);
      final group = service.findGroupByPath(widget.groupPath);
      log.d(
        '[EntryEdit] lookup uuid=${widget.entryUuid} groupPath="${widget.groupPath}" group=${group?.name} groupEntries=${group?.entries.length}',
      );
      var entry = group?.entries.where((e) => e.uuid == uuid).firstOrNull;
      if (entry == null) {
        log.w(
          '[EntryEdit] not in group, trying findEntryByUuid cacheSize=${service.allEntries.length}',
        );
        entry = service.findEntryByUuid(uuid);
        if (entry == null) {
          log.e(
            '[EntryEdit] ENTRY NOT FOUND uuid=${widget.entryUuid} groupPath="${widget.groupPath}"',
          );
        }
      }
      if (entry != null) {
        _titleCtrl.text = entry.fields['Title']?.text ?? '';
        _usernameCtrl.text = entry.fields['UserName']?.text ?? '';
        _passwordCtrl.text = entry.fields['Password']?.text ?? '';
        _urlCtrl.text = entry.fields['URL']?.text ?? '';
        _notesCtrl.text = entry.fields['Notes']?.text ?? '';
        _isEdit = true;
        _entry = entry;
        _expires = entry.times.expires;
        _expiryDate = entry.times.expiry.time;
        _totpConfig = _totpService.loadFromEntry(entry);
        _loadCustomFields(entry);
        final entryTags = entry.tags;
        if (entryTags != null) _tags.addAll(entryTags);
        return;
      }
    }

    // For new entries, store the target group but defer creation to _save(). (Bug #2 fix)
    _targetGroup = service.findGroupByPath(widget.groupPath);
  }

  void _loadCustomFields(KdbxEntry entry) {
    for (final e in entry.fields.entries) {
      if (AppConstants.isInternalField(e.key)) continue;
      final field = _CustomFieldData(
        originalKey: e.key,
        name: e.key,
        value: e.value.text,
        protected: e.value is ProtectedTextField,
      );
      field.nameCtrl.addListener(_onFormChanged);
      field.valueCtrl.addListener(_onFormChanged);
      _customFields.add(field);
    }
  }

  bool _saved = false;
  bool _hasChanges = false;

  @override
  void dispose() {
    // If creating a new entry was abandoned, permanently discard the draft
    // (do not soft-delete into recycle bin).
    if (!_saved && !_isEdit && _entry != null) {
      final service = ref.read(databaseServiceProvider);
      service.discardItem(_entry!);
      if (!_wasDirtyBeforeCreate) {
        service.markClean();
      }
      service.rebuildEntryCache();
    }
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    for (final f in _customFields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_confirmDiscardChanges());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l10n.editEntry : l10n.newEntry),
          actions: [
            TextButton(onPressed: _save, child: ButtonLabel(l10n.save)),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Basic info card
              _SectionCard(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.title,
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Password card
              _SectionCard(
                children: [
                  PasswordTextField(
                    controller: _passwordCtrl,
                    labelText: l10n.password,
                    showStrengthIndicator: true,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final password = await showPasswordGeneratorDialog(
                          context,
                        );
                        if (password != null) {
                          _passwordCtrl.text = password;
                        }
                      },
                      icon: const Icon(Icons.casino_outlined, size: 16),
                      label: ButtonLabel(l10n.generatePassword),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details card
              _SectionCard(
                children: [
                  TextFormField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.url,
                      prefixIcon: const Icon(Icons.link_rounded),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.notes,
                      prefixIcon: const Icon(Icons.note_outlined),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
              // Expiration
              const SizedBox(height: 12),
              _SectionCard(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.expiration,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Switch(
                        value: _expires,
                        onChanged: (v) {
                          setState(() {
                            _expires = v;
                            if (v && _expiryDate == null) {
                              _expiryDate = DateTime.now().add(
                                const Duration(days: 30),
                              );
                            }
                          });
                          _onFormChanged();
                        },
                      ),
                    ],
                  ),
                  if (_expires) ...[
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _expiryDate ??
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _expiryDate = picked);
                          _onFormChanged();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _expiryDate != null
                                    ? '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'
                                    : l10n.noExpiration,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (_expiryDate != null)
                              IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () {
                                  setState(() => _expiryDate = null);
                                  _onFormChanged();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Custom fields
              if (_entry != null) ...[
                const SizedBox(height: 12),
                _buildCustomFieldsSection(colorScheme, l10n),
              ],
              // Tags
              if (_entry != null) ...[
                const SizedBox(height: 12),
                _buildTagsSection(colorScheme, l10n),
              ],
              // TOTP
              if (_entry != null) ...[
                const SizedBox(height: 12),
                _buildTotpSection(colorScheme, l10n),
              ],
              // Attachments
              if (_entry != null) ...[
                const SizedBox(height: 4),
                _AttachmentsSectionWrapper(
                  entry: _entry!,
                  onFormActivity: _onFormChanged,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final service = ref.read(databaseServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    // Validate custom field names BEFORE creating a new entry so a failed
    // save never leaves a blank draft entry behind for auto-save to persist.
    final names = <String>{};
    for (final f in _customFields) {
      final name = f.nameCtrl.text.trim();
      if (name.isEmpty) {
        showToast(context, l10n.fieldNameEmpty, isError: true);
        return;
      }
      if (AppConstants.isInternalField(name)) {
        showToast(context, l10n.fieldNameReserved(name), isError: true);
        return;
      }
      if (!names.add(name)) {
        showToast(context, l10n.fieldNameDuplicate(name), isError: true);
        return;
      }
    }

    // Create entry on demand for new entries (deferred from _loadEntry, Bug #2 fix).
    if (!_isEdit && _entry == null) {
      if (_targetGroup == null) return;
      _wasDirtyBeforeCreate = service.isDirty;
      _entry = service.createEntry(_targetGroup!);
    }
    var entry = _entry;
    if (entry == null) return;

    if (_isEdit) {
      // The database instance can be replaced underneath this screen (e.g.
      // reloadFromCloud after a remote change). Resolve the live entry by
      // UUID so edits land in the database that is actually open instead of
      // an orphaned object from a replaced instance.
      final live = service.findEntryByUuid(entry.uuid);
      if (live == null) {
        if (!mounted) return;
        showToast(context, l10n.entryNoLongerExists, isError: true);
        return;
      }
      entry = live;
      _entry = live;
    }

    if (_isEdit) {
      entry.times.touch();
      entry.pushHistory();
    }
    // Avoid the inconsistent "expires=true but expiry=null" state: only honour
    // the expiry date when one is actually set.
    final effectiveExpires = _expires && _expiryDate != null;
    entry.times.expires = effectiveExpires;
    entry.times.expiry = KdbxTime(effectiveExpires ? _expiryDate : null);
    entry.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
    entry.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
    entry.fields['Password'] = KdbxTextField.fromText(
      text: _passwordCtrl.text,
      protected: true,
    );
    entry.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
    entry.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);

    // Save custom fields. TOTP internals (TimeOtp-*) are owned by TotpService
    // and must survive this cleanup.
    final currentKeys = names;
    final keysToRemove = entry.fields.keys
        .where(
          (k) => !AppConstants.isInternalField(k) && !currentKeys.contains(k),
        )
        .toList();
    for (final key in keysToRemove) {
      entry.fields.remove(key);
    }

    // Remove old keys first (separate pass to avoid data loss on field rename swaps)
    for (final f in _customFields) {
      final name = f.nameCtrl.text.trim();
      if (f.originalKey.isNotEmpty && f.originalKey != name) {
        entry.fields.remove(f.originalKey);
      }
    }
    for (final f in _customFields) {
      final name = f.nameCtrl.text.trim();
      entry.fields[name] = KdbxTextField.fromText(
        text: f.valueCtrl.text,
        protected: f.protected,
      );
    }

    // Save tags
    entry.tags = _tags.isEmpty ? null : List.from(_tags);

    // Save TOTP
    if (_totpConfig != null) {
      _totpService.saveToEntry(entry, _totpConfig!);
    } else if (_isEdit) {
      _totpService.removeFromEntry(entry);
    }

    _saved = true;
    _hasChanges = false;
    service.markDirty();
    refreshExplorerLists(ref);
    if (mounted) context.pop();
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return SectionCard(children: children);
  }
}

class _AttachmentsSectionWrapper extends ConsumerStatefulWidget {
  final KdbxEntry entry;
  final VoidCallback onFormActivity;

  const _AttachmentsSectionWrapper({
    required this.entry,
    required this.onFormActivity,
  });

  @override
  ConsumerState<_AttachmentsSectionWrapper> createState() =>
      _AttachmentsSectionWrapperState();
}

class _AttachmentsSectionWrapperState
    extends ConsumerState<_AttachmentsSectionWrapper> {
  @override
  Widget build(BuildContext context) {
    final service = ref.read(databaseServiceProvider);
    return AttachmentsSection(
      entry: widget.entry,
      service: service,
      onChanged: () {
        setState(() {});
        widget.onFormActivity();
      },
    );
  }
}
