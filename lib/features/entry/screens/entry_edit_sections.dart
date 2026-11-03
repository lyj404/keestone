part of 'entry_edit_screen.dart';

// These methods are extensions on State so the form fields remain grouped here.
// ignore_for_file: invalid_use_of_protected_member

extension _EntryEditSections on _EntryEditScreenState {
  Widget _buildTagsSection(ColorScheme colorScheme, AppLocalizations l10n) {
    return _SectionCard(
      children: [
        Row(
          children: [
            Icon(
              Icons.label_outline_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.tags,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (int i = 0; i < _tags.length; i++)
                Chip(
                  label: Text(_tags[i], style: TextStyle(fontSize: 13)),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () {
                    setState(() => _tags.removeAt(i));
                    _onFormChanged();
                  },
                  deleteIconColor: colorScheme.onSurfaceVariant,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ActionChip(
                label: ButtonLabel(l10n.addTag, style: TextStyle(fontSize: 13)),
                avatar: Icon(Icons.add_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () => _showAddTagDialog(colorScheme, l10n),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddTagDialog(ColorScheme colorScheme, AppLocalizations l10n) {
    final ctrl = TextEditingController();
    final db = ref.read(databaseServiceProvider).db;
    final existingTags = <String>{};
    if (db != null) {
      for (final entry in db.root.allEntries) {
        final entryTags = entry.tags;
        if (entryTags != null) existingTags.addAll(entryTags);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.addTag),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.tags),
                onSubmitted: (_) {
                  final tag = ctrl.text.trim();
                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                    setState(() => _tags.add(tag));
                    _onFormChanged();
                  }
                  Navigator.pop(ctx);
                },
              ),
              if (existingTags.where((t) => !_tags.contains(t)).isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in existingTags.where(
                      (t) => !_tags.contains(t),
                    ))
                      ActionChip(
                        label: Text(tag, style: TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () {
                          setState(() => _tags.add(tag));
                          _onFormChanged();
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: ButtonLabel(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final tag = ctrl.text.trim();
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() => _tags.add(tag));
                  _onFormChanged();
                }
                Navigator.pop(ctx);
              },
              child: ButtonLabel(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTotpSection(ColorScheme colorScheme, AppLocalizations l10n) {
    return _SectionCard(
      children: [
        Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'TOTP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (_totpConfig != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colorScheme.error,
                ),
                tooltip: l10n.deleteTotp,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.deleteTotp),
                      content: Text(l10n.deleteTotpConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: ButtonLabel(l10n.cancel),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                            foregroundColor: Theme.of(ctx).colorScheme.onError,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: ButtonLabel(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) setState(() => _totpConfig = null);
                  _onFormChanged();
                },
              ),
          ],
        ),
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
        if (_totpConfig != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.totpSecretLabel}: ${_totpConfig!.secret.substring(0, _totpConfig!.secret.length > 8 ? 8 : _totpConfig!.secret.length)}...',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_totpConfig!.digits} digits / ${_totpConfig!.period}s / ${_totpConfig!.algorithm}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final result = await showTotpEditSheet(
                      context,
                      initial: _totpConfig,
                      initialTitle: _titleCtrl.text,
                    );
                    if (result != null) {
                      setState(() => _totpConfig = result.config);
                    }
                    _onFormChanged();
                  },
                  child: ButtonLabel(l10n.edit),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final result = await showTotpEditSheet(context);
                  if (result != null) {
                    setState(() => _totpConfig = result.config);
                  }
                  _onFormChanged();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: ButtonLabel(l10n.setupTotp),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomFieldsSection(
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return _SectionCard(
      children: [
        for (int i = 0; i < _customFields.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          _buildCustomFieldRow(_customFields[i], colorScheme, l10n),
        ],
        if (_customFields.isNotEmpty)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _addCustomField,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: ButtonLabel(l10n.addCustomField),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFieldRow(
    _CustomFieldData field,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Field name
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: field.nameCtrl,
              focusNode: field.nameFocus,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(width: 8),
          // Field value
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: field.valueCtrl,
              obscureText: field.obscure,
              decoration: InputDecoration(
                labelText: l10n.fieldValue,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                suffixIcon: field.protected
                    ? IconButton(
                        icon: Icon(
                          field.obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => field.obscure = !field.obscure),
                      )
                    : null,
              ),
            ),
          ),
          // Protect toggle
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: Icon(
                field.protected ? Icons.shield_rounded : Icons.shield_outlined,
                size: 18,
                color: field.protected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              tooltip: field.protected
                  ? l10n.unprotectField
                  : l10n.protectField,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() {
                field.protected = !field.protected;
                field.obscure = field.protected;
              }),
            ),
          ),
          // Delete
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: colorScheme.error,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => _deleteCustomField(field),
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomField() {
    final field = _CustomFieldData(originalKey: '', name: '', value: '');
    field.nameCtrl.addListener(_onFormChanged);
    field.valueCtrl.addListener(_onFormChanged);
    setState(() => _customFields.add(field));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      field.nameFocus.requestFocus();
    });
  }

  Future<void> _deleteCustomField(_CustomFieldData field) async {
    final l10n = AppLocalizations.of(context)!;
    if (field.valueCtrl.text.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.delete),
          content: Text(l10n.deleteCustomFieldConfirm(field.nameCtrl.text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: ButtonLabel(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: ButtonLabel(l10n.delete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _customFields.remove(field);
      field.dispose();
    });
    _onFormChanged();
  }
}
