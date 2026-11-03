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
import '../../../core/widgets/button_label.dart';
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

part 'explorer_actions.dart';
part 'explorer_narrow_layout.dart';
part 'explorer_totp_list.dart';

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
                child: ButtonLabel(l10n.sync),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showSyncAuditDialog(context, ref);
                },
                child: ButtonLabel(l10n.more),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: ButtonLabel(l10n.ignore),
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
    // A local database can also be uploaded once WebDAV is configured and
    // enabled, by linking it to the active profile. The sync-up affordance is
    // therefore shown whenever cloud is already active OR a profile is ready.
    // Only the enabled flag matters here; watching the whole config would
    // rebuild the explorer whenever any WebDAV profile field changes.
    final webDavEnabled = ref.watch(
      webDavConfigProvider.select((v) => v.asData?.value?.enabled ?? false),
    );
    final canSyncToCloud = isOpenedFromCloud || webDavEnabled;
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
          canSyncToCloud: canSyncToCloud,
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
        canSyncToCloud: canSyncToCloud,
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
}
