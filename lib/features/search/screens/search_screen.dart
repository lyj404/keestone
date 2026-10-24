import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/entry_list_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../providers/search_provider.dart';
import '../../explorer/providers/explorer_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _keyboardFocusNode = FocusNode();
  Timer? _debounce;
  KdbxEntry? _selectedEntry;

  @override
  void dispose() {
    // Clear the query so a stale search (and its full-vault result
    // computation) does not survive the page for the next visit. Also drop
    // the lowercase search index: it duplicates the text of every entry and
    // is only worth keeping while a search session is active.
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(databaseServiceProvider).clearSearchIndex();
    _searchCtrl.dispose();
    _keyboardFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final service = ref.read(databaseServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
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
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(AppConstants.searchDebounceDelay, () {
              ref.read(searchQueryProvider.notifier).state = v;
            });
          },
        ),
      ),
      body: _searchCtrl.text.isEmpty
          ? EmptyState(icon: Icons.search_rounded, message: l10n.enterKeywords)
          : results.isEmpty
          ? EmptyState(icon: Icons.search_off_rounded, message: l10n.noResults)
          : KeyboardListener(
              focusNode: _keyboardFocusNode,
              autofocus: true,
              onKeyEvent: (event) {
                if (event is! KeyDownEvent) return;
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() {
                    final idx = _selectedEntry == null
                        ? -1
                        : results.indexWhere((r) => r.entry == _selectedEntry);
                    if (idx < results.length - 1) {
                      _selectedEntry = results[idx + 1].entry;
                      ref.read(activeEntryProvider.notifier).state =
                          _selectedEntry;
                    }
                  });
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() {
                    final idx = _selectedEntry == null
                        ? results.length
                        : results.indexWhere((r) => r.entry == _selectedEntry);
                    if (idx > 0) {
                      _selectedEntry = results[idx - 1].entry;
                      ref.read(activeEntryProvider.notifier).state =
                          _selectedEntry;
                    }
                  });
                } else if (event.logicalKey == LogicalKeyboardKey.enter &&
                    _selectedEntry != null) {
                  final groupPath = _selectedEntry!.parent != null
                      ? service.getGroupPath(_selectedEntry!.parent!)
                      : '';
                  final encodedUuid = Uri.encodeComponent(
                    _selectedEntry!.uuid.string,
                  );
                  context.push(
                    '/entry/detail?uuid=$encodedUuid&groupPath=${Uri.encodeComponent(groupPath)}',
                  );
                }
              },
              child: ListView.builder(
                addAutomaticKeepAlives: false,
                scrollCacheExtent: const ScrollCacheExtent.pixels(200),
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: results.length,
                itemBuilder: (ctx, i) {
                  final result = results[i];
                  final entry = result.entry;
                  final groupPath = entry.parent != null
                      ? service.getGroupPath(entry.parent!)
                      : '';
                  return RepaintBoundary(
                    child: EntryListTile(
                      key: ValueKey(entry.uuid),
                      entry: entry,
                      isSelected: entry == _selectedEntry,
                      query: _searchCtrl.text,
                      onTap: () {
                        setState(() => _selectedEntry = entry);
                        ref.read(activeEntryProvider.notifier).state = entry;
                      },
                      onOpen: () {
                        final encodedUuid = Uri.encodeComponent(
                          entry.uuid.string,
                        );
                        context.push(
                          '/entry/detail?uuid=$encodedUuid&groupPath=${Uri.encodeComponent(groupPath)}',
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
