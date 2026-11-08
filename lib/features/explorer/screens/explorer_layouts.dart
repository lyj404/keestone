part of 'explorer_screen.dart';

class _WideLayout extends ConsumerWidget {
  final List<String> breadcrumbs;
  final KdbxGroup? currentGroup;
  final List<KdbxEntry> entries;
  final KdbxEntry? selectedEntry;
  final bool isRecycleBin;
  final bool isOpenedFromCloud;
  final bool canSyncToCloud;
  final bool isCloudOfflineMode;
  final String? cloudOfflineReason;
  final bool isDirty;
  final bool isSaving;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;
  final ValueChanged<KdbxEntry>? onToggleFavoriteEntry;
  final ValueChanged<KdbxEntry>? onTogglePinEntry;
  final VoidCallback? onToggleFavoritesView;
  final ValueChanged<KdbxGroup>? onDeleteGroup;
  final ValueChanged<KdbxGroup>? onRenameGroup;
  final ValueChanged<KdbxGroup>? onRestoreGroup;
  final ValueChanged<KdbxGroup>? onPermanentDeleteGroup;
  final VoidCallback? onAddEntry;
  final VoidCallback? onAddGroup;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback? onPop;
  final VoidCallback? onImportCsv;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportKdbx;
  final EntrySortOption sortOption;
  final ValueChanged<EntrySortOption> onSortChanged;
  final bool isMultiSelect;
  final Set<KdbxEntry> selectedEntries;
  final VoidCallback onToggleMultiSelect;
  final ValueChanged<KdbxEntry> onToggleEntrySelection;
  final VoidCallback onSelectAll;
  final VoidCallback onCancelSelection;
  final VoidCallback onBatchDelete;
  final VoidCallback onBatchMove;
  final VoidCallback onBatchTag;
  final void Function(KdbxEntry entry, KdbxGroup target)? onEntryDropped;

  const _WideLayout({
    required this.breadcrumbs,
    required this.currentGroup,
    required this.entries,
    this.selectedEntry,
    required this.isRecycleBin,
    required this.isOpenedFromCloud,
    required this.canSyncToCloud,
    required this.isCloudOfflineMode,
    required this.cloudOfflineReason,
    required this.isDirty,
    required this.isSaving,
    required this.onGroupTap,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
    this.onToggleFavoriteEntry,
    this.onDeleteGroup,
    this.onRenameGroup,
    this.onRestoreGroup,
    this.onPermanentDeleteGroup,
    this.onAddEntry,
    this.onAddGroup,
    required this.onSave,
    required this.onClose,
    required this.onSearch,
    this.onPop,
    this.onImportCsv,
    this.onExportCsv,
    this.onExportKdbx,
    required this.sortOption,
    required this.onSortChanged,
    required this.isMultiSelect,
    required this.selectedEntries,
    required this.onToggleMultiSelect,
    required this.onToggleEntrySelection,
    required this.onSelectAll,
    required this.onCancelSelection,
    required this.onBatchDelete,
    required this.onBatchMove,
    required this.onBatchTag,
    this.onTogglePinEntry,
    this.onToggleFavoritesView,
    this.onEntryDropped,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark
          ? ClayColors.surfaceDark
          : ClayColors.surfaceLight,
      body: Row(
        children: [
          // Sidebar with clay feel
          Container(
            width: ClayLayout.sidebarWidth,
            decoration: BoxDecoration(
              color: isDark
                  ? ClayColors.surfaceCardDark
                  : ClayColors.surfaceCardLight,
              boxShadow: ClayDecoration.sidebarShadow(brightness),
            ),
            child: Column(
              children: [
                // Sidebar header
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'KeeStone',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            ref.watch(favoritesViewProvider)
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: ref.watch(favoritesViewProvider)
                                ? const Color(0xFFF59E0B)
                                : colorScheme.onSurfaceVariant,
                          ),
                          tooltip: l10n.favorites,
                          onPressed: onToggleFavoritesView,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          tooltip: l10n.search,
                          onPressed: onSearch,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(34, 34),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                ),
                // Group tree
                Expanded(
                  child: _GroupTreeView(
                    currentGroup: currentGroup,
                    isRecycleBin: isRecycleBin,
                    onGroupTap: onGroupTap,
                    onDeleteGroup: onDeleteGroup ?? (_) {},
                    onRenameGroup: onRenameGroup ?? (_) {},
                    onRestoreGroup: onRestoreGroup,
                    onPermanentDeleteGroup: onPermanentDeleteGroup,
                    onEntryDropped: isRecycleBin ? null : onEntryDropped,
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Toolbar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      if (onPop != null)
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                            ),
                            tooltip: l10n.back,
                            onPressed: onPop,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(34, 34),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isMultiSelect
                            ? Text(
                                l10n.selectedCount(selectedEntries.length),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              )
                            : _BreadcrumbBar(breadcrumbs: breadcrumbs),
                      ),
                      const Spacer(),
                      if (isMultiSelect) ...[
                        _ToolbarButton(
                          icon: Icons.close_rounded,
                          tooltip: l10n.cancel,
                          onPressed: onCancelSelection,
                        ),
                        _ToolbarButton(
                          icon: Icons.select_all_rounded,
                          tooltip: l10n.selectAll,
                          onPressed: onSelectAll,
                        ),
                        _ToolbarButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: l10n.batchDelete,
                          onPressed: selectedEntries.isNotEmpty
                              ? onBatchDelete
                              : null,
                        ),
                        _ToolbarButton(
                          icon: Icons.drive_file_move_rounded,
                          tooltip: l10n.batchMove,
                          onPressed: selectedEntries.isNotEmpty
                              ? onBatchMove
                              : null,
                        ),
                        _ToolbarButton(
                          icon: Icons.label_outline_rounded,
                          tooltip: l10n.batchTag,
                          onPressed: selectedEntries.isNotEmpty
                              ? onBatchTag
                              : null,
                        ),
                      ] else ...[
                        _ToolbarButton(
                          icon: Icons.save_outlined,
                          tooltip: l10n.save,
                          onPressed: onSave,
                          showDot: isDirty,
                          isLoading: isSaving,
                        ),
                        if (canSyncToCloud)
                          _ToolbarButton(
                            icon: Icons.cloud_upload_outlined,
                            tooltip: l10n.syncToCloud,
                            onPressed: () => _syncToCloud(context),
                          ),
                        _ToolbarButton(
                          icon: Icons.file_upload_outlined,
                          tooltip: l10n.importCsv,
                          onPressed: onImportCsv,
                        ),
                        _ToolbarButton(
                          icon: Icons.file_download_outlined,
                          tooltip: l10n.exportCsv,
                          onPressed: onExportCsv,
                        ),
                        _ToolbarButton(
                          icon: Icons.save_as_outlined,
                          tooltip: l10n.exportKdbx,
                          onPressed: onExportKdbx,
                        ),
                        _ToolbarButton(
                          icon: Icons.health_and_safety_outlined,
                          tooltip: l10n.passwordHealth,
                          onPressed: () => context.push('/audit'),
                        ),
                        PopupMenuButton<String>(
                          tooltip: l10n.more,
                          icon: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onSelected: (v) {
                            switch (v) {
                              case 'sync_down':
                                _syncFromCloud(context);
                              case 'settings':
                                context.push('/settings');
                              case 'about':
                                context.push('/about');
                              case 'close':
                                onClose();
                              case 'batch_select':
                                onToggleMultiSelect();
                            }
                          },
                          itemBuilder: (_) => [
                            if (isOpenedFromCloud)
                              PopupMenuItem(
                                value: 'sync_down',
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.cloud_download_rounded,
                                  ),
                                  title: Text(l10n.syncFromCloud),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'settings',
                              child: ListTile(
                                leading: const Icon(Icons.settings_rounded),
                                title: Text(l10n.settings),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'about',
                              child: ListTile(
                                leading: const Icon(Icons.info_outline_rounded),
                                title: Text(l10n.about),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'close',
                              child: ListTile(
                                leading: const Icon(Icons.close_rounded),
                                title: Text(l10n.closeDatabase),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                ),
                if (isOpenedFromCloud && isCloudOfflineMode)
                  _CloudOfflineBanner(reason: cloudOfflineReason),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: isMultiSelect
                            ? Text(l10n.selectedCount(selectedEntries.length))
                            : _BreadcrumbBar(breadcrumbs: breadcrumbs),
                      ),
                      if (isMultiSelect) ...[
                        _ToolbarButton(
                          icon: Icons.select_all_rounded,
                          tooltip: l10n.selectAll,
                          onPressed: onSelectAll,
                        ),
                        _ToolbarButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: l10n.batchDelete,
                          onPressed: selectedEntries.isNotEmpty
                              ? onBatchDelete
                              : null,
                        ),
                        _ToolbarButton(
                          icon: Icons.drive_file_move_rounded,
                          tooltip: l10n.batchMove,
                          onPressed: selectedEntries.isNotEmpty
                              ? onBatchMove
                              : null,
                        ),
                        _ToolbarButton(
                          icon: Icons.label_outline_rounded,
                          tooltip: l10n.batchTag,
                          onPressed: selectedEntries.isNotEmpty
                              ? onBatchTag
                              : null,
                        ),
                      ] else ...[
                        _SortButton(
                          sortOption: sortOption,
                          onSortChanged: onSortChanged,
                        ),
                        _ToolbarButton(
                          icon: Icons.add_rounded,
                          tooltip: l10n.addEntry,
                          onPressed: currentGroup != null ? onAddEntry : null,
                        ),
                        _ToolbarButton(
                          icon: Icons.create_new_folder_rounded,
                          tooltip: l10n.addGroup,
                          onPressed: currentGroup != null ? onAddGroup : null,
                        ),
                      ],
                      _ToolbarButton(
                        icon: isMultiSelect
                            ? Icons.close_rounded
                            : Icons.checklist_rounded,
                        tooltip: isMultiSelect ? l10n.cancel : l10n.batchSelect,
                        onPressed: isMultiSelect
                            ? onCancelSelection
                            : onToggleMultiSelect,
                      ),
                    ],
                  ),
                ),
                if (!ref.watch(favoritesViewProvider)) const _TagFilterBar(),
                Expanded(
                  child: ref.watch(favoritesViewProvider)
                      ? FavoritesView(
                          selectedEntry: selectedEntry,
                          onEntrySelect: onEntrySelect,
                          onEntryOpen: onEntryOpen,
                          onDeleteEntry: onDeleteEntry,
                          onToggleFavoriteEntry: onToggleFavoriteEntry ?? (_) {},
                        )
                      : _EntryListBody(
                    entries: entries,
                    selectedEntry: selectedEntry,
                    onEntrySelect: onEntrySelect,
                    onEntryOpen: onEntryOpen,
                    onDeleteEntry: onDeleteEntry,
                    onRestoreEntry: onRestoreEntry,
                    onMoveEntry: onMoveEntry,
                    onToggleFavoriteEntry: onToggleFavoriteEntry,
                    onTogglePinEntry: onTogglePinEntry,
                    isMultiSelect: isMultiSelect,
                    selectedEntries: selectedEntries,
                    onToggleEntrySelection: onToggleEntrySelection,
                    isDraggable: !isRecycleBin,
                  ),
                ),
                if (selectedEntry != null)
                  _ShortcutHintBar(entry: selectedEntry!),
                if (isOpenedFromCloud)
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.cloudDatabase,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (isDirty) ...[
                          const SizedBox(width: 12),
                          Text(
                            l10n.unsavedChanges,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (isOpenedFromCloud)
                          TextButton.icon(
                            onPressed: () => _syncToCloud(context),
                            icon: const Icon(
                              Icons.cloud_upload_outlined,
                              size: 17,
                            ),
                            label: Text(l10n.syncToCloud),
                          ),
                        if (isDirty)
                          TextButton.icon(
                            onPressed: onSave,
                            icon: const Icon(Icons.save_outlined, size: 17),
                            label: Text(l10n.save),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool showDot;
  final bool isLoading;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.showDot = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : showDot
            ? Badge(
                smallSize: 6,
                backgroundColor: colorScheme.primary,
                child: Icon(
                  icon,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        tooltip: tooltip,
        onPressed: isLoading ? null : onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _CloudOfflineBanner extends StatelessWidget {
  final String? reason;

  const _CloudOfflineBanner({this.reason});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: colorScheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cloudDatabase,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason ?? l10n.downloadingFromCloud,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final EntrySortOption sortOption;
  final ValueChanged<EntrySortOption> onSortChanged;
  const _SortButton({required this.sortOption, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<EntrySortOption>(
      tooltip: l10n.sortBy,
      icon: Icon(
        Icons.sort_rounded,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      onSelected: onSortChanged,
      itemBuilder: (_) => [
        _sortItem(
          l10n.sortTitleAsc,
          EntrySortOption.titleAsc,
          Icons.sort_by_alpha_rounded,
        ),
        _sortItem(
          l10n.sortTitleDesc,
          EntrySortOption.titleDesc,
          Icons.sort_by_alpha_rounded,
        ),
        const PopupMenuDivider(),
        _sortItem(
          l10n.sortCreatedNewest,
          EntrySortOption.createdNewest,
          Icons.access_time_rounded,
        ),
        _sortItem(
          l10n.sortCreatedOldest,
          EntrySortOption.createdOldest,
          Icons.access_time_rounded,
        ),
        const PopupMenuDivider(),
        _sortItem(
          l10n.sortModifiedNewest,
          EntrySortOption.modifiedNewest,
          Icons.edit_rounded,
        ),
        _sortItem(
          l10n.sortModifiedOldest,
          EntrySortOption.modifiedOldest,
          Icons.edit_rounded,
        ),
        const PopupMenuDivider(),
        _sortItem(
          l10n.sortExpiredFirst,
          EntrySortOption.expiredFirst,
          Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  PopupMenuItem<EntrySortOption> _sortItem(
    String label,
    EntrySortOption value,
    IconData icon,
  ) {
    final isSelected = sortOption == value;
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_rounded, size: 18) : null,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// ─── Narrow layout (phone) ───────────────────────────────────────────────

// ─── Group tree (sidebar) ────────────────────────────────────────────────
