import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/button_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';

class EntryHistoryScreen extends ConsumerWidget {
  final String entryUuid;
  final String groupPath;

  const EntryHistoryScreen({
    super.key,
    required this.entryUuid,
    required this.groupPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(databaseProvider);
    final service = ref.read(databaseServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    KdbxEntry? entry;
    if (entryUuid.isNotEmpty) {
      final uuid = KdbxUuid.fromString(entryUuid);
      final group = service.findGroupByPath(groupPath);
      log.d(
        '[EntryHistory] lookup uuid=$entryUuid groupPath="$groupPath" group=${group?.name} groupEntries=${group?.entries.length}',
      );
      entry = group?.entries.where((e) => e.uuid == uuid).firstOrNull;
      if (entry == null) {
        log.w(
          '[EntryHistory] not in group, trying findEntryByUuid cacheSize=${service.allEntries.length}',
        );
        entry = service.findEntryByUuid(uuid);
        if (entry == null) {
          log.e(
            '[EntryHistory] ENTRY NOT FOUND uuid=$entryUuid groupPath="$groupPath"',
          );
        }
      }
    }
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.history)),
        body: Center(child: Text(l10n.entryNotFound)),
      );
    }
    final matchedEntry = entry;
    final history = List<KdbxEntry>.from(matchedEntry.history)
      ..sort(
        (a, b) => (b.times.modification.timeOrZero).compareTo(
          a.times.modification.timeOrZero,
        ),
      );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noHistory,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              addAutomaticKeepAlives: false,
              scrollCacheExtent: const ScrollCacheExtent.pixels(200),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final historyEntry = history[index];
                return _HistoryTile(
                  historyEntry: historyEntry,
                  onTap: () => _showHistoryDetail(
                    context,
                    ref,
                    matchedEntry,
                    historyEntry,
                  ),
                );
              },
            ),
    );
  }

  void _showHistoryDetail(
    BuildContext context,
    WidgetRef ref,
    KdbxEntry currentEntry,
    KdbxEntry historyEntry,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final title = historyEntry.fields['Title']?.text ?? '';
    final username = historyEntry.fields['UserName']?.text ?? '';
    final password = historyEntry.fields['Password']?.text ?? '';
    final url = historyEntry.fields['URL']?.text ?? '';
    final notes = historyEntry.fields['Notes']?.text ?? '';
    final modTime = historyEntry.times.modification.timeOrZero;
    final timeStr =
        '${modTime.year}-${modTime.month.toString().padLeft(2, '0')}-${modTime.day.toString().padLeft(2, '0')} '
        '${modTime.hour.toString().padLeft(2, '0')}:${modTime.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
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
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (title.isNotEmpty)
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmRestore(
                            context,
                            ref,
                            currentEntry,
                            historyEntry,
                          );
                        },
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: ButtonLabel(l10n.restoreVersion),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
            // Fields
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  if (title.isNotEmpty)
                    _DetailField(label: l10n.title, value: title),
                  if (username.isNotEmpty)
                    _DetailField(label: l10n.username, value: username),
                  if (password.isNotEmpty)
                    _DetailField(
                      label: l10n.password,
                      value: password,
                      obscure: true,
                    ),
                  if (url.isNotEmpty) _DetailField(label: l10n.url, value: url),
                  if (notes.isNotEmpty)
                    _DetailField(label: l10n.notes, value: notes),
                  // Custom fields
                  for (final e in historyEntry.fields.entries)
                    if (![
                          'Title',
                          'UserName',
                          'Password',
                          'URL',
                          'Notes',
                        ].contains(e.key) &&
                        e.value.text.isNotEmpty)
                      _DetailField(label: e.key, value: e.value.text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(
    BuildContext context,
    WidgetRef ref,
    KdbxEntry currentEntry,
    KdbxEntry historyEntry,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreVersion),
        content: Text(l10n.restoreVersionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ButtonLabel(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              _restoreVersion(ref, currentEntry, historyEntry);
              Navigator.pop(ctx);
              if (context.mounted) {
                showToast(context, l10n.versionRestored);
                Navigator.pop(context); // Go back to detail screen
              }
            },
            child: ButtonLabel(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _restoreVersion(
    WidgetRef ref,
    KdbxEntry currentEntry,
    KdbxEntry historyEntry,
  ) {
    // Save current state to history before restoring.
    currentEntry.times.touch();
    currentEntry.pushHistory();

    currentEntry.fields
      ..clear()
      ..addAll(
        historyEntry.fields.map(
          (key, value) => MapEntry(key, KdbxTextField.copyFrom(value)),
        ),
      );

    currentEntry.binaries
      ..clear()
      ..addAll(
        historyEntry.binaries.map(
          (key, value) => MapEntry(key, BinaryReference(value.id)),
        ),
      );

    final tags = historyEntry.tags;
    currentEntry.tags = tags == null ? null : List<String>.from(tags);
    currentEntry.icon = historyEntry.icon;
    currentEntry.customIcon = historyEntry.customIcon;
    currentEntry.foreground = historyEntry.foreground;
    currentEntry.background = historyEntry.background;
    currentEntry.overrideUrl = historyEntry.overrideUrl;
    currentEntry.autoType
      ..enabled = historyEntry.autoType.enabled
      ..obfuscation = historyEntry.autoType.obfuscation
      ..defaultSequence = historyEntry.autoType.defaultSequence
      ..items = List.from(historyEntry.autoType.items);
    currentEntry.times = KdbxTimes.copyFrom(historyEntry.times);
    // The restore itself is a modification: keep the entry's modification
    // time at "now" instead of inheriting the historical timestamp.
    currentEntry.times.touch();
    currentEntry.previousParent = historyEntry.previousParent;

    final sourceCustomData = historyEntry.customData;
    if (sourceCustomData == null) {
      currentEntry.customData = null;
    } else {
      final customData = KdbxCustomData();
      for (final item in sourceCustomData.map.entries) {
        customData.map[item.key] = KdbxCustomItem(
          value: item.value.value,
          modification: KdbxTime(item.value.modification.time),
        );
      }
      currentEntry.customData = customData;
    }

    ref.read(databaseServiceProvider).markDirty();
    refreshExplorerLists(ref);
  }
}

class _HistoryTile extends StatelessWidget {
  final KdbxEntry historyEntry;
  final VoidCallback onTap;

  const _HistoryTile({required this.historyEntry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final modTime = historyEntry.times.modification.timeOrZero;
    final title = historyEntry.fields['Title']?.text ?? '';
    final username = historyEntry.fields['UserName']?.text ?? '';
    final timeStr =
        '${modTime.year}-${modTime.month.toString().padLeft(2, '0')}-${modTime.day.toString().padLeft(2, '0')} '
        '${modTime.hour.toString().padLeft(2, '0')}:${modTime.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: ClayDecoration.card(brightness: brightness),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: ClayDecoration.iconContainer(
                      brightness: brightness,
                      radius: 12,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title.isNotEmpty ? title : username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final bool obscure;

  const _DetailField({
    required this.label,
    required this.value,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 4),
          SelectableText(
            obscure ? '●' * value.length : value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: obscure ? 'monospace' : null,
              letterSpacing: obscure ? 2 : null,
            ),
          ),
        ],
      ),
    );
  }
}
