part of 'explorer_screen.dart';

class _MobileTotpTab extends ConsumerStatefulWidget {
  final ValueChanged<KdbxEntry> onEntryOpen;
  final TotpService totpService;

  const _MobileTotpTab({
    super.key,
    required this.onEntryOpen,
    required this.totpService,
  });

  @override
  ConsumerState<_MobileTotpTab> createState() => _MobileTotpTabState();
}

class _MobileTotpTabState extends ConsumerState<_MobileTotpTab> {
  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;
  List<KdbxEntry>? _totpCache;
  int _cacheRevision = -1;
  String _cacheQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _debounce?.cancel();
        _searchController.clear();
        _query = '';
      }
    });
  }

  Future<void> addTotpEntry(BuildContext context) async {
    final result = await showTotpEditSheet(context);
    if (result == null || !context.mounted) return;

    final service = ref.read(databaseServiceProvider);
    const groupPath = 'TOTP';
    final root = service.findGroupByPath('');
    if (root == null) return;
    final group =
        service.findGroupByPath(groupPath) ??
        service.createGroup(root, groupPath);
    final entry = service.createEntry(group);
    entry.fields['Title'] = KdbxTextField.fromText(text: result.title);
    widget.totpService.saveToEntry(entry, result.config);
    service.markDirty();
    refreshExplorerLists(ref);

    // The TOTP tab already shows the new item. Avoid pushing another route
    // after the scanner and bottom sheet close; this caused a grey page on
    // some Android devices.
  }

  Future<void> _deleteTotpEntry(KdbxEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteEntry),
        content: Text(l10n.moveToRecycleBin),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: ButtonLabel(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: ButtonLabel(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ref.read(databaseServiceProvider).deleteItem(entry);
    refreshExplorerLists(ref);
    if (mounted) showToast(context, l10n.movedToRecycleBin);
  }

  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(explorerListRevisionProvider);
    final service = ref.read(databaseServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    // Filter with the cheap hasTotp check only; full config parsing is
    // deferred to each _TotpListTile so per-build cost stays low. The result
    // is memoized per (revision, query) so keystrokes and unrelated rebuilds
    // do not rescan the vault.
    final List<KdbxEntry> totpEntries;
    final cached = _totpCache;
    if (cached != null && _cacheRevision == revision && _cacheQuery == _query) {
      totpEntries = cached;
    } else {
      final q = _query.toLowerCase();
      final filtered = <KdbxEntry>[];
      for (final entry in service.allEntries) {
        if (service.isInRecycleBin(entry)) continue;
        if (!widget.totpService.hasTotp(entry)) continue;
        if (q.isNotEmpty) {
          final title = entry.fields['Title']?.text.toLowerCase() ?? '';
          final username = entry.fields['UserName']?.text.toLowerCase() ?? '';
          if (!title.contains(q) && !username.contains(q)) continue;
        }
        filtered.add(entry);
      }
      _totpCache = filtered;
      _cacheRevision = revision;
      _cacheQuery = _query;
      totpEntries = filtered;
    }

    return Column(
      children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) setState(() => _query = v);
                });
              },
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _searching = false;
                    });
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        Expanded(
          child: totpEntries.isEmpty
              ? EmptyState(
                  icon: Icons.timer_outlined,
                  message: l10n.noTotpEntries,
                )
              : ListView.builder(
                  addAutomaticKeepAlives: false,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(200),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: totpEntries.length,
                  itemBuilder: (context, index) {
                    final entry = totpEntries[index];
                    return RepaintBoundary(
                      child: _TotpListTile(
                        key: ValueKey(entry.uuid),
                        entry: entry,
                        totpService: widget.totpService,
                        onTap: () => widget.onEntryOpen(entry),
                        onDelete: () => _deleteTotpEntry(entry),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TotpListTile extends StatefulWidget {
  final KdbxEntry entry;
  final TotpService totpService;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TotpListTile({
    super.key,
    required this.entry,
    required this.totpService,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_TotpListTile> createState() => _TotpListTileState();
}

class _TotpListTileState extends State<_TotpListTile> {
  TotpConfig? _config;
  String _code = '';
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didUpdateWidget(covariant _TotpListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.entry, oldWidget.entry)) {
      TotpTicker.instance.removeListener(_onTick);
      _config = null;
      _code = '';
      _remaining = 0;
      _loadConfig();
    }
  }

  @override
  void dispose() {
    TotpTicker.instance.removeListener(_onTick);
    super.dispose();
  }

  void _loadConfig() {
    try {
      _config = widget.totpService.loadFromEntry(widget.entry);
    } catch (_) {
      _config = null;
    }
    if (_config != null) {
      _updateCode(force: true);
      TotpTicker.instance.addListener(_onTick);
    }
  }

  void _onTick() => _updateCode();

  /// Called once per second by the shared ticker. The code only changes when
  /// the period wraps (remaining jumps back up), so the HMAC is recomputed
  /// once per period instead of on every tick.
  ///
  /// A bad secret must not throw out of initState/build — that used to leave
  /// the tile (and sometimes the list below it) as an unpainted gray hole.
  void _updateCode({bool force = false}) {
    final config = _config;
    if (config == null) return;
    final newRemaining = widget.totpService.remainingSeconds(config);
    String newCode;
    try {
      newCode = force || newRemaining > _remaining
          ? widget.totpService.generateCode(config)
          : _code;
    } catch (_) {
      newCode = '';
    }
    if (mounted && (newCode != _code || newRemaining != _remaining)) {
      setState(() {
        _code = newCode;
        _remaining = newRemaining;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final title = widget.entry.fields['Title']?.text ?? l10n.untitled;
    final isLow = _remaining <= 5;
    final progress = _config == null ? 0.0 : _remaining / _config!.period;
    final codeDisplay = _code.length == 6
        ? '${_code.substring(0, 3)} ${_code.substring(3)}'
        : _code;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: isDark
            ? ClayColors.surfaceCardDark
            : ClayColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: ClayDecoration.iconContainer(
                        brightness: brightness,
                        radius: 11,
                      ),
                      child: Icon(
                        Icons.timer_rounded,
                        size: 18,
                        color: isLow ? colorScheme.error : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      tooltip: l10n.deleteEntry,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(width: 48),
                    Text(
                      codeDisplay,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isLow ? colorScheme.error : colorScheme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            backgroundColor: colorScheme.outlineVariant
                                .withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isLow ? colorScheme.error : colorScheme.primary,
                            ),
                          ),
                          Text(
                            '$_remaining',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: isLow
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            copyToClipboardWithAutoClear(_code);
                            showToast(context, l10n.copiedTotp);
                          },
                          child: Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mobile search tab ──────────────────────────────────────────────────
