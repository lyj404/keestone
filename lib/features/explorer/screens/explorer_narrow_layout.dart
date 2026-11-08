part of 'explorer_screen.dart';

class _NarrowLayout extends ConsumerStatefulWidget {
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
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIndex: tabIndex,
        onDestinationSelected: (i) {
          ref.read(mobileTabIndexProvider.notifier).state = i;
          _closeFab();
          if (i == 2) {
            _searchDebounce?.cancel();
            _searchController.clear();
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
            label: l10n.homeTab,
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
            icon: const Icon(Icons.settings_outlined, size: 22),
            selectedIcon: Icon(
              Icons.settings_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
            label: l10n.more,
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
        return AppBar(title: Text(l10n.settings));
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
              case 'batch_select':
                widget.onToggleMultiSelect();
            }
          },
          itemBuilder: (_) => [
            if (widget.canSyncToCloud)
              PopupMenuItem(
                value: 'sync_up',
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_rounded),
                  title: Text(l10n.syncToCloud),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (widget.isOpenedFromCloud)
              PopupMenuItem(
                value: 'sync_down',
                child: ListTile(
                  leading: const Icon(Icons.cloud_download_rounded),
                  title: Text(l10n.syncFromCloud),
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
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
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
          canSyncToCloud: widget.canSyncToCloud,
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
