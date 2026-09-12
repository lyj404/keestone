part of 'explorer_screen.dart';

class _GroupTreeView extends ConsumerStatefulWidget {
  final KdbxGroup? currentGroup;
  final bool isRecycleBin;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxGroup> onDeleteGroup;
  final ValueChanged<KdbxGroup> onRenameGroup;
  final ValueChanged<KdbxGroup>? onRestoreGroup;
  final ValueChanged<KdbxGroup>? onPermanentDeleteGroup;
  final void Function(KdbxEntry entry, KdbxGroup target)? onEntryDropped;

  const _GroupTreeView({
    required this.currentGroup,
    required this.isRecycleBin,
    required this.onGroupTap,
    required this.onDeleteGroup,
    required this.onRenameGroup,
    this.onRestoreGroup,
    this.onPermanentDeleteGroup,
    this.onEntryDropped,
  });

  @override
  ConsumerState<_GroupTreeView> createState() => _GroupTreeViewState();
}

class _GroupTreeViewState extends ConsumerState<_GroupTreeView> {
  final Set<KdbxGroup> _expanded = {};
  final Set<KdbxGroup> _dragOverGroups = {};
  KdbxDatabase? _lastDb;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider).value;
    if (db == null) return const SizedBox.shrink();

    // Expand all groups when database changes (first open or reload from cloud).
    if (!identical(db, _lastDb)) {
      _lastDb = db;
      _expanded.clear();
      _expandAll(db.root);
    }

    final visible = _flattenVisible(db.root);

    return ListView.builder(
      addAutomaticKeepAlives: false,
      scrollCacheExtent: const ScrollCacheExtent.pixels(200),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        final tile = RepaintBoundary(
          child: _buildGroupTile(context, item.group, item.depth),
        );
        if (widget.onEntryDropped == null) return tile;
        return DragTarget<KdbxEntry>(
          onWillAcceptWithDetails: (details) {
            final entry = details.data;
            return entry.parent != item.group;
          },
          onAcceptWithDetails: (details) {
            setState(() => _dragOverGroups.remove(item.group));
            widget.onEntryDropped!(details.data, item.group);
          },
          onLeave: (_) {
            setState(() => _dragOverGroups.remove(item.group));
          },
          onMove: (_) {
            if (!_dragOverGroups.contains(item.group)) {
              setState(() => _dragOverGroups.add(item.group));
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isDragOver = _dragOverGroups.contains(item.group);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: isDragOver
                  ? BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    )
                  : null,
              child: tile,
            );
          },
        );
      },
    );
  }

  List<_GroupItem> _flattenVisible(KdbxGroup root) {
    final result = <_GroupItem>[];
    result.add(_GroupItem(root, 0));
    _flattenChildren(root, 1, result);
    return result;
  }

  void _flattenChildren(KdbxGroup group, int depth, List<_GroupItem> result) {
    if (!_expanded.contains(group)) return;
    for (final child in group.groups) {
      result.add(_GroupItem(child, depth));
      _flattenChildren(child, depth + 1, result);
    }
  }

  void _expandAll(KdbxGroup group) {
    _expanded.add(group);
    for (final child in group.groups) {
      _expandAll(child);
    }
  }

  Widget _buildGroupTile(BuildContext context, KdbxGroup group, int depth) {
    final isSelected = group == widget.currentGroup;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(databaseServiceProvider);
    final isTrashGroup = service.isRecycleBinGroup(group);
    final canDelete = depth > 0 && !isTrashGroup;
    final hasChildren = group.groups.isNotEmpty;
    final isExpanded = _expanded.contains(group);
    final displayName = isTrashGroup ? l10n.recycleBin : group.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(
                      alpha: brightness == Brightness.dark ? 0.15 : 0.1,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => widget.onGroupTap(group),
              onSecondaryTapUp: canDelete
                  ? (details) {
                      if (group == widget.currentGroup) {
                        _showContextMenu(
                          context,
                          details.globalPosition,
                          group,
                        );
                      } else {
                        widget.onGroupTap(group);
                      }
                    }
                  : null,
              onLongPress: canDelete
                  ? () {
                      if (group == widget.currentGroup) {
                        final box = context.findRenderObject() as RenderBox?;
                        final pos =
                            box?.localToGlobal(Offset.zero) ?? Offset.zero;
                        final size = box?.size ?? Size.zero;
                        _showContextMenu(
                          context,
                          Offset(
                            pos.dx + size.width / 2,
                            pos.dy + size.height / 2,
                          ),
                          group,
                        );
                      } else {
                        widget.onGroupTap(group);
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 36,
                padding: EdgeInsets.only(left: 12.0 + depth * 18, right: 12),
                child: Row(
                  children: [
                    if (hasChildren)
                      GestureDetector(
                        onTap: () => setState(() {
                          if (isExpanded) {
                            _expanded.remove(group);
                          } else {
                            _expanded.add(group);
                          }
                        }),
                        child: Icon(
                          isExpanded
                              ? Icons.expand_more_rounded
                              : Icons.chevron_right_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 4),
                    Icon(
                      group.icon == KdbxIcon.trashBin
                          ? (isSelected
                                ? Icons.delete_rounded
                                : Icons.delete_outline_rounded)
                          : depth == 0
                          ? (isSelected
                                ? Icons.folder_open_rounded
                                : Icons.folder_open_outlined)
                          : (isSelected
                                ? Icons.folder_rounded
                                : Icons.folder_outlined),
                      size: 18,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (group.entries.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${group.entries.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset globalPos,
    KdbxGroup group,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isTrashGroup = group.icon == KdbxIcon.trashBin;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final screenSize = overlay.size;
    final position = RelativeRect.fromLTRB(
      globalPos.dx,
      globalPos.dy,
      screenSize.width - globalPos.dx,
      screenSize.height - globalPos.dy,
    );
    showMenu<String>(
      context: context,
      position: position,
      items: [
        if (!widget.isRecycleBin && !isTrashGroup) ...[
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.rename),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.deleteGroup),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        if (widget.isRecycleBin && !isTrashGroup) ...[
          PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: Text(l10n.restore),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'permanent_delete',
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded),
              title: Text(l10n.permanentDelete),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'rename') widget.onRenameGroup(group);
      if (value == 'delete') widget.onDeleteGroup(group);
      if (value == 'restore') widget.onRestoreGroup?.call(group);
      if (value == 'permanent_delete') {
        widget.onPermanentDeleteGroup?.call(group);
      }
    });
  }
}

class _GroupItem {
  final KdbxGroup group;
  final int depth;
  const _GroupItem(this.group, this.depth);
}

// ─── Breadcrumb bar ──────────────────────────────────────────────────────
