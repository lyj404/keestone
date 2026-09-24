part of 'explorer_screen.dart';

class _WideLayout extends StatelessWidget {
  final List<String> breadcrumbs;
  final KdbxGroup? currentGroup;
  final List<KdbxEntry> entries;
  final KdbxEntry? selectedEntry;
  final bool isRecycleBin;
  final bool isOpenedFromCloud;
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
    this.onEntryDropped,
  });

  @override
  Widget build(BuildContext context) {
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
                        if (isOpenedFromCloud)
                          _ToolbarButton(
                            icon: Icons.sync_rounded,
                            tooltip: l10n.syncFromCloud,
                            onPressed: () => _syncFromCloud(context),
                          ),
                        _ToolbarButton(
                          icon: Icons.save_outlined,
                          tooltip: l10n.save,
                          onPressed: onSave,
                          showDot: isDirty,
                          isLoading: isSaving,
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
                              case 'sync_up':
                                _syncToCloud(context);
                              case 'sync_down':
                                _syncFromCloud(context);
                              case 'import_csv':
                                onImportCsv?.call();
                              case 'export_csv':
                                onExportCsv?.call();
                              case 'export_kdbx':
                                onExportKdbx?.call();
                              case 'password_audit':
                                context.push('/audit');
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
                            if (isOpenedFromCloud) ...[
                              PopupMenuItem(
                                value: 'sync_up',
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.cloud_upload_rounded,
                                  ),
                                  title: Text(l10n.syncToCloud),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
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
                            ],
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'import_csv',
                              child: ListTile(
                                leading: const Icon(Icons.file_upload_rounded),
                                title: Text(l10n.importCsv),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'export_csv',
                              child: ListTile(
                                leading: const Icon(
                                  Icons.file_download_rounded,
                                ),
                                title: Text(l10n.exportCsv),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'export_kdbx',
                              child: ListTile(
                                leading: const Icon(Icons.save_as_rounded),
                                title: Text(l10n.exportKdbx),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'password_audit',
                              child: ListTile(
                                leading: const Icon(
                                  Icons.health_and_safety_outlined,
                                ),
                                title: Text(l10n.passwordHealth),
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
                              value: 'batch_select',
                              child: ListTile(
                                leading: const Icon(Icons.checklist_rounded),
                                title: Text(l10n.batchSelect),
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
                // Tag filter bar
                _TagFilterBar(),
                // Entry list
                Expanded(
                  child: _EntryListBody(
                    entries: entries,
                    selectedEntry: selectedEntry,
                    onEntrySelect: onEntrySelect,
                    onEntryOpen: onEntryOpen,
                    onDeleteEntry: onDeleteEntry,
                    onRestoreEntry: onRestoreEntry,
                    onMoveEntry: onMoveEntry,
                    isMultiSelect: isMultiSelect,
                    selectedEntries: selectedEntries,
                    onToggleEntrySelection: onToggleEntrySelection,
                    isDraggable: !isRecycleBin,
                  ),
                ),
                // Shortcut hint bar (hidden on mobile where keyboard shortcuts are unavailable)
                if (selectedEntry != null &&
                    !Platform.isAndroid &&
                    !Platform.isIOS)
                  _ShortcutHintBar(entry: selectedEntry!),
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

class _NarrowLayout extends ConsumerStatefulWidget {
  final List<String> breadcrumbs;
  final KdbxGroup? currentGroup;
  final List<KdbxEntry> entries;
  final KdbxEntry? selectedEntry;
  final bool isRecycleBin;
  final bool isOpenedFromCloud;
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

  const _NarrowLayout({
    required this.breadcrumbs,
    required this.currentGroup,
    required this.entries,
    this.selectedEntry,
    required this.isRecycleBin,
    required this.isOpenedFromCloud,
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
  });

  @override
  ConsumerState<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends ConsumerState<_NarrowLayout> {
  final _searchController = TextEditingController();
  final _totpService = TotpService();
  final _totpTabKey = GlobalKey();
  bool _fabExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
  }

  void _closeFab() {
    if (_fabExpanded) setState(() => _fabExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final tabIndex = ref.watch(mobileTabIndexProvider);

    return Scaffold(
      appBar: _buildAppBar(context, l10n, colorScheme, tabIndex),
      body: GestureDetector(
        onTap: _closeFab,
        behavior: HitTestBehavior.translucent,
        child: _buildBody(context, l10n, colorScheme, isDark, tabIndex),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) {
          ref.read(mobileTabIndexProvider.notifier).state = i;
          _closeFab();
          if (i == 2) {
            ref.read(searchQueryProvider.notifier).state = '';
          }
        },
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.list_alt_rounded, size: 22),
            selectedIcon: Icon(
              Icons.list_alt_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
            label: l10n.entriesTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.timer_outlined, size: 22),
            selectedIcon: Icon(
              Icons.timer_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
            label: l10n.totpTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded, size: 22),
            selectedIcon: Icon(
              Icons.search_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
            label: l10n.searchTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.build_outlined, size: 22),
            selectedIcon: Icon(
              Icons.build_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
            label: l10n.toolsTab,
          ),
        ],
      ),
      floatingActionButton: _buildFab(context, l10n, colorScheme, tabIndex),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0:
        return _buildEntriesAppBar(context, l10n, colorScheme);
      case 1:
        return AppBar(
          title: Text(l10n.totpTab),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: l10n.search,
              onPressed: () {
                final state = _totpTabKey.currentState;
                if (state is _MobileTotpTabState) {
                  state.toggleSearch();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: l10n.addEntry,
              onPressed: () {
                final state = _totpTabKey.currentState;
                if (state is _MobileTotpTabState) {
                  state.addTotpEntry(context);
                }
              },
            ),
          ],
        );
      case 2:
        return _buildSearchAppBar(context, l10n, colorScheme);
      case 3:
        return AppBar(title: Text(l10n.toolsTab));
      default:
        return AppBar(title: Text(l10n.entriesTab));
    }
  }

  PreferredSizeWidget _buildEntriesAppBar(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (widget.isMultiSelect) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: widget.onCancelSelection,
        ),
        title: Text(l10n.selectedCount(widget.selectedEntries.length)),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            tooltip: l10n.selectAll,
            onPressed: widget.onSelectAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: l10n.batchDelete,
            onPressed: widget.selectedEntries.isNotEmpty
                ? widget.onBatchDelete
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move_rounded),
            tooltip: l10n.batchMove,
            onPressed: widget.selectedEntries.isNotEmpty
                ? widget.onBatchMove
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.label_outline_rounded),
            tooltip: l10n.batchTag,
            onPressed: widget.selectedEntries.isNotEmpty
                ? widget.onBatchTag
                : null,
          ),
        ],
      );
    }
    return AppBar(
      leading: widget.onPop != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onPop,
            )
          : null,
      title: Text(widget.breadcrumbs.last, overflow: TextOverflow.ellipsis),
      actions: [
        if (widget.isOpenedFromCloud)
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 20),
            tooltip: l10n.syncFromCloud,
            onPressed: () => _syncFromCloud(context),
          ),
        _SortButton(
          sortOption: widget.sortOption,
          onSortChanged: widget.onSortChanged,
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 20),
          tooltip: l10n.search,
          onPressed: () => ref.read(mobileTabIndexProvider.notifier).state = 2,
        ),
        IconButton(
          icon: widget.isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : widget.isDirty
              ? Badge(
                  smallSize: 6,
                  backgroundColor: colorScheme.primary,
                  child: const Icon(Icons.save_outlined, size: 20),
                )
              : const Icon(Icons.save_outlined, size: 20),
          tooltip: l10n.save,
          onPressed: widget.isSaving ? null : widget.onSave,
        ),
        PopupMenuButton<String>(
          tooltip: l10n.more,
          onSelected: (v) {
            switch (v) {
              case 'sync_up':
                _syncToCloud(context);
              case 'sync_down':
                _syncFromCloud(context);
              case 'import_csv':
                widget.onImportCsv?.call();
              case 'export_csv':
                widget.onExportCsv?.call();
              case 'export_kdbx':
                widget.onExportKdbx?.call();
              case 'password_audit':
                context.push('/audit');
              case 'batch_select':
                widget.onToggleMultiSelect();
            }
          },
          itemBuilder: (_) => [
            if (widget.isOpenedFromCloud) ...[
              PopupMenuItem(
                value: 'sync_up',
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_rounded),
                  title: Text(l10n.syncToCloud),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'sync_down',
                child: ListTile(
                  leading: const Icon(Icons.cloud_download_rounded),
                  title: Text(l10n.syncFromCloud),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'import_csv',
              child: ListTile(
                leading: const Icon(Icons.file_upload_rounded),
                title: Text(l10n.importCsv),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'export_csv',
              child: ListTile(
                leading: const Icon(Icons.file_download_rounded),
                title: Text(l10n.exportCsv),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'export_kdbx',
              child: ListTile(
                leading: const Icon(Icons.save_as_rounded),
                title: Text(l10n.exportKdbx),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'password_audit',
              child: ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: Text(l10n.passwordHealth),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'batch_select',
              child: ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: Text(l10n.batchSelect),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: l10n.searchEntries,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 15,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Timer? _searchDebounce;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isDark,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0:
        return _buildEntriesTab(context, l10n, colorScheme, isDark);
      case 1:
        return _MobileTotpTab(
          key: _totpTabKey,
          onEntryOpen: widget.onEntryOpen,
          totpService: _totpService,
        );
      case 2:
        return _MobileSearchTab(onEntryOpen: widget.onEntryOpen);
      case 3:
        return _MobileToolsPanel(
          isOpenedFromCloud: widget.isOpenedFromCloud,
          isCloudOfflineMode: widget.isCloudOfflineMode,
          cloudOfflineReason: widget.cloudOfflineReason,
          onClose: widget.onClose,
          onImportCsv: widget.onImportCsv,
          onExportCsv: widget.onExportCsv,
          onExportKdbx: widget.onExportKdbx,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEntriesTab(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Column(
      children: [
        if (widget.isOpenedFromCloud && widget.isCloudOfflineMode)
          _CloudOfflineBanner(reason: widget.cloudOfflineReason),
        _TagFilterBar(),
        Expanded(
          child: _MobileEntryListBody(
            currentGroup: widget.currentGroup,
            entries: widget.entries,
            selectedEntry: widget.selectedEntry,
            onGroupTap: widget.onGroupTap,
            onEntrySelect: widget.onEntrySelect,
            onEntryOpen: widget.onEntryOpen,
            onDeleteEntry: widget.onDeleteEntry,
            onRestoreEntry: widget.onRestoreEntry,
            onMoveEntry: widget.onMoveEntry,
            onDeleteGroup: widget.onDeleteGroup,
            onRenameGroup: widget.onRenameGroup,
            onRestoreGroup: widget.onRestoreGroup,
            onPermanentDeleteGroup: widget.onPermanentDeleteGroup,
            isMultiSelect: widget.isMultiSelect,
            selectedEntries: widget.selectedEntries,
            onToggleEntrySelection: widget.onToggleEntrySelection,
          ),
        ),
        if (widget.selectedEntry != null &&
            !Platform.isAndroid &&
            !Platform.isIOS)
          _ShortcutHintBar(entry: widget.selectedEntry!),
      ],
    );
  }

  Widget? _buildFab(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    int tabIndex,
  ) {
    if (tabIndex != 0) return null;
    if (widget.currentGroup == null) return null;
    if (widget.onAddEntry == null && widget.onAddGroup == null) return null;

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          _FabOption(
            icon: Icons.create_new_folder_rounded,
            label: l10n.addGroup,
            colorScheme: colorScheme,
            isDark: isDark,
            onTap: () {
              _closeFab();
              widget.onAddGroup?.call();
            },
          ),
          const SizedBox(height: 10),
          _FabOption(
            icon: Icons.add_rounded,
            label: l10n.addEntry,
            colorScheme: colorScheme,
            isDark: isDark,
            onTap: () {
              _closeFab();
              widget.onAddEntry?.call();
            },
          ),
          const SizedBox(height: 14),
        ],
        FloatingActionButton(
          onPressed: widget.onAddEntry != null && widget.onAddGroup != null
              ? _toggleFab
              : (widget.onAddEntry ?? _toggleFab),
          tooltip: l10n.addEntry,
          backgroundColor: isDark ? colorScheme.primaryContainer : null,
          foregroundColor: isDark ? colorScheme.onPrimaryContainer : null,
          elevation: isDark ? 4 : null,
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onTap;

  const _FabOption({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? ClayColors.surfaceContainerDark
                : ClayColors.surfaceContainerLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.4 : 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? ClayColors.onSurfaceDark
                      : ClayColors.onSurfaceLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Group tree (sidebar) ────────────────────────────────────────────────
