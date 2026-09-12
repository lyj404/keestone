import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../database/providers/database_provider.dart';
import '../../database/data/database_service.dart';
import '../../explorer/providers/explorer_provider.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Maximum number of ranked search results retained. Keeps the working set
/// bounded for very large vaults; the full list is only materialised when the
/// user scrolls further (re-query with a more specific term).
const searchResultLimit = 200;

final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider);
  // Re-run after database swaps (open/reload/cloud sync) and after any
  // mutation (add/edit/delete) so results stay in sync with current state.
  ref.watch(databaseProvider);
  ref.watch(explorerListRevisionProvider);
  if (query.isEmpty) return [];
  final service = ref.read(databaseServiceProvider);
  if (query.isEmpty) {
    // No active search: drop the lowercase index. It duplicates the text of
    // every entry, so it should only exist while a search session is live;
    // the next search rebuilds it on demand.
    service.clearSearchIndex();
    return [];
  }
  return service.search(query, limit: searchResultLimit);
});