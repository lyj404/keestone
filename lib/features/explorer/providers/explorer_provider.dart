import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../database/providers/database_provider.dart';

final currentGroupPathProvider = StateProvider<String>((ref) => '');

final currentGroupProvider = Provider<KdbxGroup?>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) return null;
  final path = ref.watch(currentGroupPathProvider);
  final service = ref.read(databaseServiceProvider);
  return service.findGroupByPath(path) ?? db.root;
});

/// Currently selected tag filter (null means show all entries).
final selectedTagProvider = StateProvider<String?>((ref) => null);

/// All unique tags across the entire database, sorted alphabetically.
final allTagsProvider = Provider<List<String>>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) return [];
  final service = ref.read(databaseServiceProvider);
  final sorted = service.allTags.toList()..sort();
  return sorted;
});

/// Whether a save operation is currently in progress.
final isSavingProvider = StateProvider<bool>((ref) => false);

/// Whether the current group is the recycle bin.
final isRecycleBinProvider = Provider<bool>((ref) {
  final group = ref.watch(currentGroupProvider);
  if (group == null) return false;
  final db = ref.watch(databaseProvider).value;
  if (db == null) return false;
  final recycleBinUuid = db.meta.recycleBinUuid;
  if (recycleBinUuid == null) return false;
  return group.uuid == recycleBinUuid;
});

/// Entries for the current group, filtered by the selected tag.
final entriesProvider = Provider<List<KdbxEntry>>((ref) {
  final group = ref.watch(currentGroupProvider);
  final selectedTag = ref.watch(selectedTagProvider);
  final sortOption = ref.watch(entrySortOptionProvider);
  if (group == null) return [];
  var entries = [...group.entries];
  if (selectedTag != null) {
    entries = entries.where((e) => e.tags?.contains(selectedTag) ?? false).toList();
  }
  // Apply sorting
  entries.sort((a, b) {
    switch (sortOption) {
      case EntrySortOption.titleAsc:
        return (a.fields['Title']?.text ?? '').compareTo(b.fields['Title']?.text ?? '');
      case EntrySortOption.titleDesc:
        return (b.fields['Title']?.text ?? '').compareTo(a.fields['Title']?.text ?? '');
      case EntrySortOption.createdNewest:
        return (b.times.creation.time ?? DateTime(0)).compareTo(a.times.creation.time ?? DateTime(0));
      case EntrySortOption.createdOldest:
        return (a.times.creation.time ?? DateTime(0)).compareTo(b.times.creation.time ?? DateTime(0));
      case EntrySortOption.modifiedNewest:
        return (b.times.modification.time ?? DateTime(0)).compareTo(a.times.modification.time ?? DateTime(0));
      case EntrySortOption.modifiedOldest:
        return (a.times.modification.time ?? DateTime(0)).compareTo(b.times.modification.time ?? DateTime(0));
      case EntrySortOption.expiredFirst:
        final aExpired = a.times.expiry.time;
        final bExpired = b.times.expiry.time;
        final now = DateTime.now();
        final aIsExpired = a.times.expires && aExpired != null && aExpired.isBefore(now);
        final bIsExpired = b.times.expires && bExpired != null && bExpired.isBefore(now);
        if (aIsExpired && !bIsExpired) return -1;
        if (!aIsExpired && bIsExpired) return 1;
        return (aExpired ?? DateTime(2100)).compareTo(bExpired ?? DateTime(2100));
    }
  });
  return entries;
});

/// Currently selected entry in the explorer (for keyboard shortcuts).
final selectedEntryProvider = StateProvider<KdbxEntry?>((ref) => null);

/// Active entry for global keyboard shortcuts (Ctrl+B/C).
/// Updated by explorer, search, and detail screens.
final activeEntryProvider = StateProvider<KdbxEntry?>((ref) => null);

/// Incremented after database mutations so views backed by DatabaseService caches
/// (such as the mobile TOTP tab) rebuild as well.
final explorerListRevisionProvider = StateProvider<int>((ref) => 0);

/// Call after any mutation (add/delete/edit) to refresh explorer-backed lists.
void refreshExplorerLists(WidgetRef ref) {
  ref.invalidate(entriesProvider);
  ref.invalidate(allTagsProvider);
  ref.read(selectedEntryProvider.notifier).state = null;
  ref.read(explorerListRevisionProvider.notifier).state++;
}

final breadcrumbProvider = Provider<List<String>>((ref) {
  final path = ref.watch(currentGroupPathProvider);
  if (path.isEmpty) return ['Root'];
  return ['Root', ...path.split('/')];
});

/// Entry sort options.
enum EntrySortOption {
  titleAsc,
  titleDesc,
  createdNewest,
  createdOldest,
  modifiedNewest,
  modifiedOldest,
  expiredFirst,
}

/// Current sort option for the entry list.
final entrySortOptionProvider = StateProvider<EntrySortOption>(
  (ref) => EntrySortOption.titleAsc,
);

/// Whether multi-select mode is active.
final isMultiSelectModeProvider = StateProvider<bool>((ref) => false);

/// Set of currently selected entries in multi-select mode.
final selectedEntriesProvider = StateProvider<Set<KdbxEntry>>((ref) => {});

/// Current mobile bottom tab index (0=Entries, 1=Totp, 2=Search, 3=Tools).
final mobileTabIndexProvider = StateProvider<int>((ref) => 0);
