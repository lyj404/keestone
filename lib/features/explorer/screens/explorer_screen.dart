import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import '../../../core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/widgets/confirm_dialogs.dart';
import '../../../core/widgets/password_generator_dialog.dart';
import '../../../core/widgets/entry_list_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/move_to_group_dialog.dart';
import '../../../core/widgets/attachments_section.dart';
import '../../../core/services/background_service.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/data/database_service.dart'
    show DatabaseService, SyncAuditChange, SyncAuditReport;
import '../../database/providers/database_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../../sync/data/sync_service.dart' show SyncException, SyncErrorType;
import '../../totp/data/totp_service.dart';
import '../../totp/data/totp_ticker.dart';
import '../../totp/widgets/totp_edit_sheet.dart';
import '../../search/providers/search_provider.dart';
import '../providers/explorer_provider.dart';
part 'explorer_layouts.dart';
part 'explorer_group_tree.dart';
part 'explorer_lists.dart';
part 'explorer_sheets.dart';
part 'explorer_bottom_bars.dart';

class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(databaseProvider);

    return dbAsync.when(
      data: (db) {
        if (db == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/welcome');
          });
          return const SizedBox.shrink();
        }
        return const _ExplorerBody();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context)!.error(e.toString())),
        ),
      ),
    );
  }
}

class _ExplorerBody extends ConsumerStatefulWidget {
  const _ExplorerBody();

  @override
  ConsumerState<_ExplorerBody> createState() => _ExplorerBodyState();
}

class _ExplorerBodyState extends ConsumerState<_ExplorerBody>
    with WidgetsBindingObserver {
  bool _offlineDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkRemoteChangesOnResume();
    }
  }

  Future<void> _checkRemoteChangesOnResume() async {
    final isOpenedFromCloud = ref.read(openedFromCloudProvider);
    if (!isOpenedFromCloud) return;
    final bool hasChanges;
    try {
      hasChanges = await ref
          .read(databaseProvider.notifier)
          .checkRemoteChanges();
    } catch (e) {
      // Best-effort background check: offline/auth errors surface elsewhere.
      log.w('Remote change check on resume failed', error: e);
      return;
    }
    if (hasChanges && mounted) {
      _showAutoSyncDialog();
    }
  }

  void _showAutoSyncDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cloudNewVersion),
        content: Text(l10n.cloudModifiedSyncLatest),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _syncFromCloud(context);
                },
                child: Text(l10n.sync),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showSyncAuditDialog(context, ref);
                },
                child: Text(l10n.more),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.ignore),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCloudOfflineMode = ref.watch(cloudOfflineModeProvider);
    final cloudOfflineReason = ref.watch(cloudOfflineReasonProvider);
    if (isCloudOfflineMode && !_offlineDialogShown) {
      _offlineDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showOfflineModeDialog(cloudOfflineReason);
      });
    }
    if (!isCloudOfflineMode) {
      _offlineDialogShown = false;
    }

    final currentGroup = ref.watch(currentGroupProvider);
    final entries = ref.watch(entriesProvider);
    final breadcrumbs = ref.watch(breadcrumbProvider);
    final isWide = ClayLayout.isWide(context);
    final service = ref.read(databaseServiceProvider);
    final isRecycleBin = ref.watch(isRecycleBinProvider);
    final isOpenedFromCloud = ref.watch(openedFromCloudProvider);
    final isDirty = ref.watch(isDirtyProvider);
    final isSaving = ref.watch(isSavingProvider);
    final selectedEntry = ref.watch(selectedEntryProvider);
    final isMultiSelect = ref.watch(isMultiSelectModeProvider);
    final selectedEntries = ref.watch(selectedEntriesProvider);
    final sortOption = ref.watch(entrySortOptionProvider);

    void onEntrySelect(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
      ref.read(activeEntryProvider.notifier).state = entry;
    }

    void onEntryOpen(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
      ref.read(activeEntryProvider.notifier).state = entry;
      final path = currentGroup != null
          ? service.getGroupPath(currentGroup)
          : '';
      final encodedUuid = Uri.encodeComponent(entry.uuid.string);
      log.d(
        '[Explorer] onEntryOpen uuid=${entry.uuid.string} groupPath="$path" entryParent=${entry.parent?.name}',
      );
      context.push(
        '/entry/detail?uuid=$encodedUuid&groupPath=${Uri.encodeComponent(path)}',
      );
    }

    if (isWide) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final pop = _popPath(ref);
          if (pop != null) {
            pop();
          } else {
            context.go('/welcome');
          }
        },
        child: _WideLayout(
          breadcrumbs: breadcrumbs,
          currentGroup: currentGroup,
          entries: entries,
          selectedEntry: selectedEntry,
          isRecycleBin: isRecycleBin,
          isOpenedFromCloud: isOpenedFromCloud,
          isCloudOfflineMode: isCloudOfflineMode,
          cloudOfflineReason: cloudOfflineReason,
          isDirty: isDirty,
          isSaving: isSaving,
          onGroupTap: (group) {
            ref.read(selectedEntryProvider.notifier).state = null;
            ref.read(activeEntryProvider.notifier).state = null;
            final path = service.getGroupPath(group);
            ref.read(currentGroupPathProvider.notifier).state = path;
          },
          onEntrySelect: onEntrySelect,
          onEntryOpen: onEntryOpen,
          onDeleteEntry: isRecycleBin
              ? (entry) => _permanentDeleteEntry(context, ref, entry)
              : (entry) => _deleteEntry(context, ref, entry),
          onRestoreEntry: isRecycleBin
              ? (entry) => _restoreEntry(context, ref, entry)
              : null,
          onMoveEntry: isRecycleBin
              ? null
              : (entry) => _moveEntry(context, ref, entry, currentGroup!),
          onDeleteGroup: isRecycleBin
              ? null
              : (group) => _deleteGroup(context, ref, group),
          onRenameGroup: isRecycleBin
              ? null
              : (group) => _renameGroup(context, ref, group),
          onRestoreGroup: isRecycleBin
              ? (group) => _restoreGroup(context, ref, group)
              : null,
          onPermanentDeleteGroup: isRecycleBin
              ? (group) => _permanentDeleteGroup(context, ref, group)
              : null,
          onAddEntry: isRecycleBin
              ? null
              : () => _showAddEntrySheet(context, ref, currentGroup!),
          onAddGroup: isRecycleBin
              ? null
              : () => _showAddGroupSheet(context, ref, currentGroup!),
          onSave: () => _save(context, ref),
          onClose: () => _close(context, ref),
          onSearch: () => context.push('/search'),
          onPop: _popPath(ref),
          onImportCsv: () => _importCsv(context, ref),
          onExportCsv: () => _exportCsv(context, ref),
          onExportKdbx: () => _exportKdbx(context, ref),
          sortOption: sortOption,
          onSortChanged: _onSortChanged,
          isMultiSelect: isMultiSelect,
          selectedEntries: selectedEntries,
          onToggleMultiSelect: _toggleMultiSelect,
          onToggleEntrySelection: _toggleEntrySelection,
          onSelectAll: () => _selectAllEntries(entries),
          onCancelSelection: _cancelSelection,
          onBatchDelete: () => _batchDelete(context, ref),
          onBatchMove: () => _batchMove(context, ref),
          onBatchTag: () => _batchTag(context, ref),
          onEntryDropped: isRecycleBin
              ? null
              : (entry, target) {
                  if (entry.parent == target) return;
                  ref.read(databaseServiceProvider).moveItem(entry, target);
                  refreshExplorerLists(ref);
                  if (context.mounted) {
                    showToast(context, AppLocalizations.of(context)!.moved);
                  }
                },
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ref.read(mobileTabIndexProvider) != 0) {
          // Any non-Entries tab returns to the Entries tab first.
          ref.read(mobileTabIndexProvider.notifier).state = 0;
          return;
        }
        final pop = _popPath(ref);
        if (pop != null) {
          pop();
        } else if (BackgroundService.isSupported) {
          // Mobile: back at the root group sends the app to the background
          // instead of leaving the database screen.
          BackgroundService.moveToBackground();
        } else {
          context.go('/welcome');
        }
      },
      child: _NarrowLayout(
        breadcrumbs: breadcrumbs,
        currentGroup: currentGroup,
        entries: entries,
        selectedEntry: selectedEntry,
        isRecycleBin: isRecycleBin,
        isOpenedFromCloud: isOpenedFromCloud,
        isCloudOfflineMode: isCloudOfflineMode,
        cloudOfflineReason: cloudOfflineReason,
        isDirty: isDirty,
        isSaving: isSaving,
        onGroupTap: (group) {
          ref.read(selectedEntryProvider.notifier).state = null;
          ref.read(activeEntryProvider.notifier).state = null;
          final path = service.getGroupPath(group);
          ref.read(currentGroupPathProvider.notifier).state = path;
        },
        onEntrySelect: onEntrySelect,
        onEntryOpen: onEntryOpen,
        onDeleteEntry: isRecycleBin
            ? (entry) => _permanentDeleteEntry(context, ref, entry)
            : (entry) => _deleteEntry(context, ref, entry),
        onRestoreEntry: isRecycleBin
            ? (entry) => _restoreEntry(context, ref, entry)
            : null,
        onMoveEntry: isRecycleBin
            ? null
            : (entry) => _moveEntry(context, ref, entry, currentGroup!),
        onDeleteGroup: isRecycleBin
            ? null
            : (group) => _deleteGroup(context, ref, group),
        onRenameGroup: isRecycleBin
            ? null
            : (group) => _renameGroup(context, ref, group),
        onRestoreGroup: isRecycleBin
            ? (group) => _restoreGroup(context, ref, group)
            : null,
        onPermanentDeleteGroup: isRecycleBin
            ? (group) => _permanentDeleteGroup(context, ref, group)
            : null,
        onAddEntry: isRecycleBin
            ? null
            : () => _showAddEntrySheet(context, ref, currentGroup!),
        onAddGroup: isRecycleBin
            ? null
            : () => _showAddGroupSheet(context, ref, currentGroup!),
        onSave: () => _save(context, ref),
        onClose: () => _close(context, ref),
        onSearch: () => context.push('/search'),
        onPop: _popPath(ref),
        onImportCsv: () => _importCsv(context, ref),
        onExportCsv: () => _exportCsv(context, ref),
        onExportKdbx: () => _exportKdbx(context, ref),
        sortOption: sortOption,
        onSortChanged: _onSortChanged,
        isMultiSelect: isMultiSelect,
        selectedEntries: selectedEntries,
        onToggleMultiSelect: _toggleMultiSelect,
        onToggleEntrySelection: _toggleEntrySelection,
        onSelectAll: () => _selectAllEntries(entries),
        onCancelSelection: _cancelSelection,
        onBatchDelete: () => _batchDelete(context, ref),
        onBatchMove: () => _batchMove(context, ref),
        onBatchTag: () => _batchTag(context, ref),
      ),
    );
  }

  void _showOfflineModeDialog(String? reason) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cloudDatabase),
        content: Text(reason ?? l10n.downloadingFromCloud),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _syncFromCloud(context);
            },
            child: Text(l10n.syncFromCloud),
          ),
        ],
      ),
    );
  }

  void _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    KdbxEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showMoveToRecycleBinDialog(
      context: context,
      title: l10n.deleteEntry,
      message: l10n.moveToRecycleBin,
    );
    if (confirmed) {
      ref.read(databaseServiceProvider).deleteItem(entry);
      refreshExplorerLists(ref);
      if (context.mounted) showToast(context, l10n.movedToRecycleBin);
    }
  }

  void _permanentDeleteEntry(
    BuildContext context,
    WidgetRef ref,
    KdbxEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showPermanentDeleteDialog(
      context: context,
      title: l10n.permanentDelete,
      message: l10n.permanentDeleteConfirm,
    );
    if (confirmed) {
      final service = ref.read(databaseServiceProvider);
      service.discardItem(entry);
      service.markDirty();
      refreshExplorerLists(ref);
      if (context.mounted) showToast(context, l10n.permanentlyDeleted);
    }
  }

  void _restoreEntry(BuildContext context, WidgetRef ref, KdbxEntry entry) {
    final service = ref.read(databaseServiceProvider);
    final success = service.restoreItem(entry);
    final l10n = AppLocalizations.of(context)!;
    if (success) {
      refreshExplorerLists(ref);
      showToast(context, l10n.restored);
    } else {
      showToast(context, l10n.restoreFailed, isError: true);
    }
  }

  void _restoreGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    final service = ref.read(databaseServiceProvider);
    final success = service.restoreItem(group);
    final l10n = AppLocalizations.of(context)!;
    if (success) {
      refreshExplorerLists(ref);
      showToast(context, l10n.restored);
    } else {
      showToast(context, l10n.restoreFailed, isError: true);
    }
  }

  void _permanentDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    KdbxGroup group,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showPermanentDeleteDialog(
      context: context,
      title: l10n.permanentDelete,
      message: l10n.permanentDeleteConfirm,
    );
    if (confirmed) {
      final service = ref.read(databaseServiceProvider);
      service.discardItem(group);
      service.markDirty();
      refreshExplorerLists(ref);
      if (context.mounted) showToast(context, l10n.permanentlyDeleted);
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
    if (context.mounted) {
      showToast(context, AppLocalizations.of(context)!.moved);
    }
  }

  void _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    KdbxGroup group,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (group.entries.isNotEmpty || group.groups.isNotEmpty) {
      showToast(context, l10n.cannotDeleteNonEmptyGroup, isError: true);
      return;
    }
    final confirmed = await showMoveToRecycleBinDialog(
      context: context,
      title: l10n.deleteGroup,
      message: l10n.deleteGroupConfirm(group.name),
    );
    if (confirmed) {
      ref.read(databaseServiceProvider).deleteItem(group);
      refreshExplorerLists(ref);
      if (context.mounted) showToast(context, l10n.movedToRecycleBin);
    }
  }

  void _renameGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameGroup),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              final service = ref.read(databaseServiceProvider);
              final oldPath = service.getGroupPath(group);
              group.name = newName;
              service.markDirty();
              final newPath = service.getGroupPath(group);
              final currentPath = ref.read(currentGroupPathProvider);
              if (currentPath == oldPath ||
                  currentPath.startsWith('$oldPath/')) {
                ref
                    .read(currentGroupPathProvider.notifier)
                    .state = currentPath == oldPath
                    ? newPath
                    : currentPath.replaceFirst('$oldPath/', '$newPath/');
              }
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  VoidCallback? _popPath(WidgetRef ref) {
    final breadcrumbs = ref.read(breadcrumbProvider);
    if (breadcrumbs.length <= 1) return null;
    return () {
      final current = ref.read(currentGroupPathProvider);
      final parts = current.split('/')..removeLast();
      ref.read(currentGroupPathProvider.notifier).state = parts.join('/');
    };
  }

  void _save(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final isSaving = ref.read(isSavingProvider.notifier);
    isSaving.state = true;

    try {
      final success = await ref.read(databaseProvider.notifier).save();
      if (!context.mounted) return;
      if (success) {
        showToast(context, l10n.saved);
      } else {
        // Only a genuine remote conflict offers the "overwrite cloud" dialog.
        // Local save failures, unreachable servers or an aborted save must
        // not be presented as conflicts — the overwrite option is destructive.
        final syncState = ref.read(syncStateProvider);
        if (syncState == SyncState.conflict) {
          _showConflictDialog(context, ref);
        } else {
          showToast(context, l10n.saveFailed, isError: true);
        }
      }
    } catch (e) {
      log.e('Save failed', error: e);
      if (context.mounted) {
        showToast(context, l10n.saveFailed, isError: true);
      }
    } finally {
      isSaving.state = false;
    }
  }

  void _showConflictDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncConflict),
        content: Text(l10n.syncConflictMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSyncAuditDialog(context, ref);
            },
            child: Text(l10n.more),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncFromCloud(context);
            },
            child: Text(l10n.downloadCloudVersion),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _forceUpload(context, ref);
            },
            child: Text(l10n.overwriteCloud),
          ),
        ],
      ),
    );
  }

  void _forceUpload(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.read(databaseProvider.notifier).forceUpload().then((_) {
      if (context.mounted) {
        final syncState = ref.read(syncStateProvider);
        if (syncState == SyncState.success) {
          showToast(context, l10n.overwrittenToCloud);
        } else if (syncState == SyncState.error) {
          showToast(context, l10n.syncFailed, isError: true);
        }
      }
    });
  }

  Future<void> _showSyncAuditDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    SyncAuditReport? report;
    try {
      report = await ref.read(databaseProvider.notifier).inspectCloudDiff();
    } catch (e) {
      log.e('Failed to inspect cloud diff', error: e);
    }
    if (!context.mounted) return;
    if (report == null || !report.hasChanges) {
      showToast(context, l10n.syncFailed, isError: true);
      return;
    }
    final audit = report;

    unawaited(
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.syncConflict),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAuditSection(ctx, 'Local Only', audit.localOnly),
                const SizedBox(height: 12),
                _buildAuditSection(ctx, 'Cloud Only', audit.remoteOnly),
                const SizedBox(height: 12),
                _buildAuditSection(ctx, 'Modified Both', audit.modifiedBoth),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _syncFromCloud(context);
            },
             child: Text(l10n.downloadCloudVersion),
           ),
           FilledButton(
             onPressed: () {
               Navigator.of(ctx).pop();
               _forceUpload(context, ref);
             },
             child: Text(l10n.overwriteCloud),
           ),
         ],
       ),
      ),
    );
  }

  Widget _buildAuditSection(
    BuildContext context,
    String title,
    List<SyncAuditChange> changes,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${changes.length})',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        if (changes.isEmpty)
          Text('-', style: TextStyle(color: colorScheme.onSurfaceVariant))
        else
          ...changes.take(8).map((change) {
            final groupPath = change.groupPath ?? '';
            final details = change.details;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showAuditChangeDetail(context, title, change),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        change.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (groupPath.isNotEmpty)
                        Text(
                          groupPath,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      if (details.isNotEmpty)
                        Text(
                          details
                              .map((detail) => _humanizeAuditKey(l10n, detail))
                              .join(', '),
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showAuditChangeDetail(
    BuildContext context,
    String sectionTitle,
    SyncAuditChange change,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final localKeys = change.localValues.keys.toSet();
    final remoteKeys = change.remoteValues.keys.toSet();
    final keys = <String>{...localKeys, ...remoteKeys}.toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(change.title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                if ((change.groupPath ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    change.groupPath!,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                if (keys.isEmpty)
                  Text(
                    l10n.syncAuditNoDiffDetails,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  )
                else
                  ...keys.map(
                    (key) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _humanizeAuditKey(l10n, key),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._buildAuditValueLines(
                            l10n,
                            key,
                            change.localValues[key],
                            change.remoteValues[key],
                            colorScheme,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx)!.close),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAuditValueLines(
    AppLocalizations l10n,
    String key,
    String? localValue,
    String? remoteValue,
    ColorScheme colorScheme,
  ) {
    if (key == 'Tags' || key == 'Attachments') {
      final localSet = _splitAuditSet(localValue);
      final remoteSet = _splitAuditSet(remoteValue);
      final onlyLocal = localSet.difference(remoteSet).toList()..sort();
      final onlyCloud = remoteSet.difference(localSet).toList()..sort();

      return [
        Text(
          '${l10n.syncAuditLocalValue}: ${localValue?.isNotEmpty == true ? localValue : '-'}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        Text(
          '${l10n.syncAuditCloudValue}: ${remoteValue?.isNotEmpty == true ? remoteValue : '-'}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        if (onlyLocal.isNotEmpty)
          Text(
            '${l10n.syncAuditAddedOnlyLocal}: ${onlyLocal.join(', ')}',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        if (onlyCloud.isNotEmpty)
          Text(
            '${l10n.syncAuditAddedOnlyCloud}: ${onlyCloud.join(', ')}',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
      ];
    }

    return [
      Text(
        '${l10n.syncAuditLocalValue}: ${localValue?.isNotEmpty == true ? localValue : '-'}',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      Text(
        '${l10n.syncAuditCloudValue}: ${remoteValue?.isNotEmpty == true ? remoteValue : '-'}',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    ];
  }

  Set<String> _splitAuditSet(String? value) {
    if (value == null || value.trim().isEmpty) return <String>{};
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  String _humanizeAuditKey(AppLocalizations l10n, String key) {
    if (key.startsWith('Field:')) {
      final field = key.substring('Field:'.length);
      switch (field) {
        case 'Title':
          return l10n.title;
        case 'UserName':
          return l10n.username;
        case 'Password':
          return l10n.password;
        case 'URL':
          return l10n.url;
        case 'Notes':
          return l10n.notes;
        default:
          return '${l10n.customFields}: $field';
      }
    }
    switch (key) {
      case 'Tags':
        return l10n.tags;
      case 'Attachments':
        return l10n.attachments;
      case 'History':
        return l10n.history;
      case 'ModifiedTime':
        return l10n.syncAuditModifiedTime;
      default:
        return key;
    }
  }

  void _close(BuildContext context, WidgetRef ref) {
    unawaited(_closeAsync(context, ref));
  }

  Future<void> _closeAsync(BuildContext context, WidgetRef ref) async {
    await ref.read(databaseProvider.notifier).close();
    if (context.mounted) context.go('/welcome');
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null) return;

    try {
      final file = result.files.single;
      final bytes =
          file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        if (context.mounted) {
          showToast(context, l10n.importFailed('No file data'), isError: true);
        }
        return;
      }

      // Try UTF-8 first, fall back to system encoding (handles GBK/ANSI on Chinese Windows)
      String content = utf8.decode(bytes, allowMalformed: true);
      // If UTF-8 decoding produced no line breaks (corrupted encoding), retry with system encoding
      if (!content.contains('\n') && bytes.length > 10) {
        final alt = systemEncoding.decode(bytes);
        if (alt.contains('\n')) {
          log.i(
            'CSV import: UTF-8 produced no line breaks, using system encoding',
          );
          content = alt;
        }
      }

      log.i('CSV import: file = ${file.name}, bytes = ${bytes.length}');
      log.i(
        'CSV import: content length = ${content.length}, line count = ${content.split('\n').length}',
      );
      final csvService = ref.read(csvServiceProvider);
      final entries = csvService.importFromCsv(content);
      if (entries.isEmpty) {
        if (context.mounted) {
          showToast(context, l10n.noEntriesInCsv, isError: true);
        }
        return;
      }

      final dbService = ref.read(databaseServiceProvider);
      final db = dbService.db;
      if (db == null) {
        if (context.mounted) {
          showToast(
            context,
            l10n.importFailed('Database not open'),
            isError: true,
          );
        }
        return;
      }
      final groupPath = ref.read(currentGroupPathProvider);
      final targetGroup = dbService.findGroupByPath(groupPath) ?? db.root;

      final count = csvService.createEntries(entries, db, targetGroup);
      dbService.markDirty();
      dbService.rebuildEntryCache();
      refreshExplorerLists(ref);

      if (context.mounted) {
        showToast(context, l10n.importSuccess(count));
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, l10n.importFailed(e.toString()), isError: true);
      }
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final dbService = ref.read(databaseServiceProvider);
    final entries = dbService.allEntries;
    if (entries.isEmpty) {
      if (context.mounted) {
        showToast(context, l10n.noEntriesToExport, isError: true);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.csvPlaintextWarningTitle),
        content: Text(l10n.csvPlaintextWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final csvService = ref.read(csvServiceProvider);
    final csvContent = csvService.exportToCsv(entries);
    final csvBytes = Uint8List.fromList(utf8.encode(csvContent));

    try {
      // Android/iOS saveFile requires bytes; desktop picks a path then we write.
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportCsv,
        fileName: 'passwords.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: (Platform.isAndroid || Platform.isIOS) ? csvBytes : null,
      );
      if (savePath == null || !context.mounted) return;

      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(savePath).writeAsBytes(csvBytes);
      }
      if (context.mounted) showToast(context, l10n.exportSuccess);
    } catch (e) {
      if (context.mounted) showToast(context, l10n.exportFailed, isError: true);
    }
  }

  Future<void> _exportKdbx(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final dbService = ref.read(databaseServiceProvider);
    if (dbService.db == null) return;

    try {
      final bytes = await dbService.saveToBytes();
      final isMobile = Platform.isAndroid || Platform.isIOS;
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportKdbx,
        fileName: 'database.kdbx',
        type: isMobile ? FileType.any : FileType.custom,
        allowedExtensions: isMobile ? null : ['kdbx'],
        bytes: isMobile ? bytes : null,
      );
      if (savePath == null || !context.mounted) return;

      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(savePath).writeAsBytes(bytes);
      }
      if (context.mounted) showToast(context, l10n.exportSuccess);
    } catch (e) {
      if (context.mounted) showToast(context, l10n.exportFailed, isError: true);
    }
  }

  void _showAddEntrySheet(
    BuildContext context,
    WidgetRef ref,
    KdbxGroup group,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddEntrySheet(group: group),
    );
  }

  // Sort and batch operations
  void _onSortChanged(EntrySortOption option) {
    ref.read(entrySortOptionProvider.notifier).state = option;
  }

  void _toggleMultiSelect() {
    final isMulti = ref.read(isMultiSelectModeProvider);
    ref.read(isMultiSelectModeProvider.notifier).state = !isMulti;
    if (isMulti) {
      ref.read(selectedEntriesProvider.notifier).state = {};
    }
  }

  void _toggleEntrySelection(KdbxEntry entry) {
    final selected = ref.read(selectedEntriesProvider);
    final newSet = {...selected};
    if (newSet.contains(entry)) {
      newSet.remove(entry);
    } else {
      newSet.add(entry);
    }
    ref.read(selectedEntriesProvider.notifier).state = newSet;
  }

  void _selectAllEntries(List<KdbxEntry> entries) {
    ref.read(selectedEntriesProvider.notifier).state = {...entries};
  }

  void _cancelSelection() {
    ref.read(isMultiSelectModeProvider.notifier).state = false;
    ref.read(selectedEntriesProvider.notifier).state = {};
  }

  Future<void> _batchDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.read(selectedEntriesProvider);
    if (selected.isEmpty) return;
    final confirmed = await showMoveToRecycleBinDialog(
      context: context,
      title: l10n.batchDelete,
      message: l10n.batchDeleteConfirm(selected.length),
    );
    if (!confirmed) return;
    final service = ref.read(databaseServiceProvider);
    for (final entry in selected) {
      service.deleteItem(entry);
    }
    _cancelSelection();
    refreshExplorerLists(ref);
    if (context.mounted) showToast(context, l10n.movedToRecycleBin);
  }

  Future<void> _batchMove(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(selectedEntriesProvider);
    if (selected.isEmpty) return;
    final service = ref.read(databaseServiceProvider);
    final db = ref.read(databaseProvider).valueOrNull;
    if (db == null) return;
    final currentGroup = ref.read(currentGroupProvider);
    final target = await showMoveToGroupDialog(
      context,
      db: db,
      excludeGroup: currentGroup,
    );
    if (target == null) return;
    for (final entry in selected) {
      service.moveItem(entry, target);
    }
    _cancelSelection();
    refreshExplorerLists(ref);
  }

  Future<void> _batchTag(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.read(selectedEntriesProvider);
    if (selected.isEmpty) return;
    final tagController = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.batchTagTitle),
        content: TextField(
          controller: tagController,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.batchTagHint),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, tagController.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    tagController.dispose();
    if (tag == null || tag.isEmpty) return;
    for (final entry in selected) {
      final tags = entry.tags ?? [];
      if (!tags.contains(tag)) {
        entry.tags = [...tags, tag];
      }
    }
    ref.read(databaseServiceProvider).markDirty();
    _cancelSelection();
    refreshExplorerLists(ref);
  }

  void _showAddGroupSheet(
    BuildContext context,
    WidgetRef ref,
    KdbxGroup group,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddGroupSheet(group: group),
    );
  }
}
