part of 'explorer_screen.dart';

class _AddEntrySheet extends ConsumerStatefulWidget {
  final KdbxGroup group;
  const _AddEntrySheet({required this.group});

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<String> _tags = [];
  bool _obscure = true;
  KdbxEntry? _entry;
  bool _saved = false;
  bool _wasDirtyBeforeCreate = false;
  late final DatabaseService _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(databaseServiceProvider);
    _wasDirtyBeforeCreate = _service.isDirty;
    _entry = _service.createEntry(widget.group);
  }

  @override
  void dispose() {
    // Do not use `ref` here: dispose can run after the element is gone.
    if (!_saved && _entry != null) {
      // Permanent discard (not recycle-bin) for abandoned draft entries.
      _service.discardItem(_entry!);
      // Restore dirty state: if database was clean before createEntry,
      // revert to clean since we're discarding the only change.
      if (!_wasDirtyBeforeCreate) {
        _service.markClean();
      }
      _service.rebuildEntryCache();
    }
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // Handle + header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.add_rounded, size: 16, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(l10n.newEntry, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                      const Spacer(),
                      TextButton(onPressed: _save, child: Text(l10n.save)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
            // Form
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: [
                  TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l10n.title, prefixIcon: const Icon(Icons.title_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(labelText: l10n.username, prefixIcon: const Icon(Icons.person_outline_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          IconButton(
                            icon: const Icon(Icons.casino_outlined, size: 18),
                            tooltip: l10n.generatePassword,
                            onPressed: () async {
                              final password = await showPasswordGeneratorDialog(context);
                              if (password != null) {
                                _passwordCtrl.text = password;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(labelText: l10n.url, prefixIcon: const Icon(Icons.link_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.notes, prefixIcon: const Icon(Icons.note_outlined)),
                  ),
                  // Tags
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (int i = 0; i < _tags.length; i++)
                          Chip(
                            label: Text(_tags[i], style: TextStyle(fontSize: 13)),
                            visualDensity: VisualDensity.compact,
                            onDeleted: () => setState(() => _tags.removeAt(i)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showAddTagDialog(l10n),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(l10n.addTag),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ),
                  if (_entry != null) ...[
                    const SizedBox(height: 8),
                    AttachmentsSection(
                      entry: _entry!,
                      service: ref.read(databaseServiceProvider),
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog(AppLocalizations l10n) {
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
                    for (final tag in existingTags.where((t) => !_tags.contains(t)))
                      ActionChip(
                        label: Text(tag, style: TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () {
                          setState(() => _tags.add(tag));
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                final tag = ctrl.text.trim();
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() => _tags.add(tag));
                }
                Navigator.pop(ctx);
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  void _save() {
    if (_entry == null) return;
    _entry!.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
    _entry!.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
    _entry!.fields['Password'] = KdbxTextField.fromText(text: _passwordCtrl.text, protected: true);
    _entry!.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
    _entry!.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);
    _entry!.tags = _tags.isEmpty ? null : List.from(_tags);
    _saved = true;
    final service = ref.read(databaseServiceProvider);
    service.markDirty();
    refreshExplorerLists(ref);
    Navigator.pop(context);
  }
}

// ─── Add group bottom sheet ──────────────────────────────────────────────

class _AddGroupSheet extends ConsumerStatefulWidget {
  final KdbxGroup group;
  const _AddGroupSheet({required this.group});

  @override
  ConsumerState<_AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends ConsumerState<_AddGroupSheet> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.create_new_folder_rounded, size: 16, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.newGroup, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                    const Spacer(),
                    TextButton(onPressed: _save, child: Text(l10n.save)),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.groupName,
                prefixIcon: const Icon(Icons.folder_outlined),
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.isEmpty) return;
    final service = ref.read(databaseServiceProvider);
    service.createGroup(widget.group, _nameCtrl.text);
    refreshExplorerLists(ref);
    if (mounted) Navigator.pop(context);
  }
}

// ─── Tag filter bar ────────────────────────────────────────────────────
