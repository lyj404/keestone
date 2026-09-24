import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/attachments_section.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/move_to_group_dialog.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';
import '../../totp/widgets/totp_display_widget.dart';

class EntryDetailScreen extends ConsumerWidget {
  final String entryUuid;
  final String groupPath;

  const EntryDetailScreen({
    super.key,
    required this.entryUuid,
    required this.groupPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch databaseProvider so this screen rebuilds after cloud sync (reloadFromCloud)
    // which replaces the entire KdbxDatabase instance.
    ref.watch(databaseProvider);
    // Mutations (e.g. edit → save) bump this revision; without it the detail
    // page would keep showing the pre-edit snapshot until re-entered.
    ref.watch(explorerListRevisionProvider);
    final service = ref.read(databaseServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    // Look up entry: try the specified group first (faster, matches explorer list),
    // fall back to full cache scan.
    KdbxEntry? entry;
    if (entryUuid.isNotEmpty) {
      final uuid = KdbxUuid.fromString(entryUuid);
      final group = service.findGroupByPath(groupPath);
      log.d(
        '[EntryDetail] lookup uuid=$entryUuid groupPath="$groupPath" group=${group?.name} groupEntries=${group?.entries.length}',
      );
      entry = group?.entries.where((e) => e.uuid == uuid).firstOrNull;
      if (entry == null) {
        log.w(
          '[EntryDetail] not in group, trying findEntryByUuid cacheSize=${service.allEntries.length}',
        );
        entry = service.findEntryByUuid(uuid);
        if (entry == null) {
          log.e(
            '[EntryDetail] ENTRY NOT FOUND uuid=$entryUuid groupPath="$groupPath" dbOpen=${service.isOpen}',
          );
        } else {
          log.i(
            '[EntryDetail] found via cache, entry parent=${entry.parent?.name}',
          );
        }
      }
    }
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.entry)),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          message: l10n.entryNotFound,
        ),
      );
    }
    final matchedEntry = entry;

    // Set active entry for global keyboard shortcuts (Ctrl+B/Ctrl+Shift+C)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ref.read(activeEntryProvider.notifier).state = matchedEntry;
      }
    });
    final title = matchedEntry.fields['Title']?.text ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final group = matchedEntry.parent;
    // Check recycle bin using database metadata instead of icon comparison.
    final db = ref.read(databaseServiceProvider).db;
    final recycleBinUuid = db?.meta.recycleBinUuid;
    final isInRecycleBin =
        recycleBinUuid != null && group?.uuid == recycleBinUuid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title.isEmpty ? l10n.entryDetail : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isInRecycleBin)
            IconButton(
              icon: Icon(
                Icons.restore_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              tooltip: l10n.restore,
              onPressed: () => _restoreEntry(context, ref, matchedEntry),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.history_rounded, size: 20),
              tooltip: l10n.history,
              onPressed: () => context.push(
                '/entry/history?uuid=${Uri.encodeComponent(entryUuid)}&groupPath=${Uri.encodeComponent(groupPath)}',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              tooltip: l10n.edit,
              onPressed: () => context.push(
                '/entry/edit?uuid=${Uri.encodeComponent(entryUuid)}&groupPath=${Uri.encodeComponent(groupPath)}',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move_rounded, size: 20),
              tooltip: l10n.move,
              onPressed: group != null
                  ? () => _moveEntry(context, ref, matchedEntry, group)
                  : null,
            ),
          ],
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: colorScheme.error,
            ),
            tooltip: isInRecycleBin ? l10n.permanentDelete : l10n.delete,
            onPressed: () => isInRecycleBin
                ? _permanentDeleteEntry(context, ref, matchedEntry)
                : group != null
                ? _deleteEntry(context, ref, matchedEntry, group)
                : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Title card
          if (title.isNotEmpty)
            _SectionCard(
              children: [_FieldRow(label: l10n.title, value: title)],
            ),
          // Credentials card
          _SectionCard(
            children: [
              _FieldRow(
                label: l10n.username,
                value: matchedEntry.fields['UserName']?.text ?? '',
                showCopy: true,
              ),
              _PasswordField(
                value: matchedEntry.fields['Password']?.text ?? '',
              ),
            ],
          ),
          // TOTP
          TotpDisplayWidget(entry: matchedEntry),
          // Details card
          if ((matchedEntry.fields['URL']?.text ?? '').isNotEmpty ||
              (matchedEntry.fields['Notes']?.text ?? '').isNotEmpty)
            _SectionCard(
              children: [
                _FieldRow(
                  label: l10n.url,
                  value: matchedEntry.fields['URL']?.text ?? '',
                  showCopy: true,
                ),
                _FieldRow(
                  label: l10n.notes,
                  value: matchedEntry.fields['Notes']?.text ?? '',
                  multiline: true,
                ),
              ],
            ),
          // Tags
          if (matchedEntry.tags != null && matchedEntry.tags!.isNotEmpty)
            _SectionCard(children: [_TagsRow(tags: matchedEntry.tags!)]),
          // Expiration
          if (matchedEntry.times.expires &&
              matchedEntry.times.expiry.time != null)
            _SectionCard(
              children: [
                _ExpirationRow(expiryDate: matchedEntry.times.expiry.time!),
              ],
            ),
          // Custom fields (TOTP internals like TimeOtp-* stay in the TOTP card)
          ...() {
            final custom = matchedEntry.fields.entries
                .where((e) => !AppConstants.isInternalField(e.key))
                .toList();
            if (custom.isEmpty) return <Widget>[];
            return [
              _SectionCard(
                children: [
                  for (final e in custom)
                    if (e.value is ProtectedTextField)
                      _PasswordField(value: e.value.text, label: e.key)
                    else
                      _FieldRow(
                        label: e.key,
                        value: e.value.text,
                        showCopy: true,
                      ),
                ],
              ),
            ];
          }(),
          // Attachments
          if (matchedEntry.binaries.isNotEmpty) ...[
            AttachmentsSection(
              entry: matchedEntry,
              service: ref.read(databaseServiceProvider),
              readOnly: true,
            ),
          ],
        ],
      ),
    );
  }

  void _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    KdbxEntry entry,
    KdbxGroup group,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEntry),
        content: Text(l10n.moveToRecycleBin),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ref.read(databaseServiceProvider).deleteItem(entry);
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) {
                showToast(context, l10n.movedToRecycleBin);
                context.pop();
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _permanentDeleteEntry(
    BuildContext context,
    WidgetRef ref,
    KdbxEntry entry,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permanentDelete),
        content: Text(l10n.permanentDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              final service = ref.read(databaseServiceProvider);
              service.discardItem(entry);
              service.markDirty();
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) {
                showToast(context, l10n.permanentlyDeleted);
                context.pop();
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _restoreEntry(BuildContext context, WidgetRef ref, KdbxEntry entry) {
    final service = ref.read(databaseServiceProvider);
    final success = service.restoreItem(entry);
    final l10n = AppLocalizations.of(context)!;
    if (success) {
      refreshExplorerLists(ref);
      if (context.mounted) {
        showToast(context, l10n.restored);
        context.pop();
      }
    } else {
      if (context.mounted) {
        showToast(context, l10n.restoreFailed, isError: true);
      }
    }
  }

  Future<void> _moveEntry(
    BuildContext context,
    WidgetRef ref,
    KdbxEntry entry,
    KdbxGroup currentGroup,
  ) async {
    final db = ref.read(databaseServiceProvider).db;
    if (db == null) return;
    final target = await showMoveToGroupDialog(
      context,
      db: db,
      excludeGroup: currentGroup,
    );
    if (target == null) return;
    ref.read(databaseServiceProvider).moveItem(entry, target);
    refreshExplorerLists(ref);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showToast(context, l10n.moved);
    context.pop();
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.where((c) {
      if (c is _FieldRow && c.value.isEmpty) return false;
      if (c is _PasswordField && c.value.isEmpty) return false;
      return true;
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      children: [
        for (int i = 0; i < visibleChildren.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
          visibleChildren[i],
        ],
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showCopy;
  final bool multiline;

  const _FieldRow({
    required this.label,
    required this.value,
    this.showCopy = false,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
              if (showCopy) ...[
                const Spacer(),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    tooltip: l10n.copy,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      copyToClipboardWithAutoClear(value);
                      showToast(context, l10n.copiedField(label));
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: multiline ? 1.5 : null),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final String value;
  final String? label;
  const _PasswordField({required this.value, this.label});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    if (widget.value.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.label ?? l10n.password,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  icon: Icon(
                    _visible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 15,
                  ),
                  tooltip: _visible ? l10n.hide : l10n.show,
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  tooltip: l10n.copy,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    copyToClipboardWithAutoClear(widget.value);
                    showToast(context, l10n.copiedPassword);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            _visible ? widget.value : '●' * widget.value.length,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: _visible ? null : 'monospace',
              letterSpacing: _visible ? null : 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  final List<String> tags;
  const _TagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tags,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final tag in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpirationRow extends StatelessWidget {
  final DateTime expiryDate;
  const _ExpirationRow({required this.expiryDate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isExpired = expiryDate.isBefore(now);
    final dateStr =
        '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.expiration,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isExpired ? Icons.warning_rounded : Icons.schedule_rounded,
                size: 18,
                color: isExpired
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                isExpired ? l10n.expired : l10n.expiresOn(dateStr),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isExpired ? colorScheme.error : null,
                  fontWeight: isExpired ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
