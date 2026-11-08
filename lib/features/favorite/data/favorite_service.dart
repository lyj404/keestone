import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';

/// Custom-data key marking an entry as a favorite. Stored in entry
/// customData (KeePass-compatible), so favorites survive sync/merge and
/// stay visible to other KeePass clients as harmless metadata.
const _kFavoriteKey = 'keestone Favorite';
const _kFavoriteValue = 'true';

/// Custom-data key marking an entry as pinned. A pinned entry floats to the
/// top of its own group's list — unlike favorites, pins are scoped to the
/// group and have no dedicated view.
const _kPinnedKey = 'keestone Pinned';
const _kPinnedValue = 'true';

/// Read-only favorite check usable from any context (list tiles, detail…).
bool isFavoriteEntry(KdbxEntry entry) =>
    entry.customData?.map[_kFavoriteKey]?.value == _kFavoriteValue;

/// Read-only pin check.
bool isPinnedEntry(KdbxEntry entry) =>
    entry.customData?.map[_kPinnedKey]?.value == _kPinnedValue;

/// Toggles the favorite flag on [entry] and bumps the explorer revision so
/// lists re-sort. Returns the new favorite state.
bool toggleFavorite(WidgetRef ref, KdbxEntry entry) {
  final service = ref.read(databaseServiceProvider);
  final newState = !isFavoriteEntry(entry);
  if (newState) {
    entry.customData ??= KdbxCustomData();
    entry.customData!.map[_kFavoriteKey] = KdbxCustomItem(
      value: _kFavoriteValue,
    );
  } else {
    entry.customData?.map.remove(_kFavoriteKey);
  }
  service.markDirty();
  refreshExplorerLists(ref);
  return newState;
}

/// Toggles the pin flag on [entry]. Returns the new pinned state.
bool togglePin(WidgetRef ref, KdbxEntry entry) {
  final service = ref.read(databaseServiceProvider);
  final newState = !isPinnedEntry(entry);
  if (newState) {
    entry.customData ??= KdbxCustomData();
    entry.customData!.map[_kPinnedKey] = KdbxCustomItem(value: _kPinnedValue);
  } else {
    entry.customData?.map.remove(_kPinnedKey);
  }
  service.markDirty();
  refreshExplorerLists(ref);
  return newState;
}

/// Favorites across the open vault, excluding the recycle bin. Rebuilt when
/// the explorer revision changes (which [toggleFavorite] always bumps).
final favoritesProvider = Provider<List<KdbxEntry>>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) return [];
  ref.watch(explorerListRevisionProvider);
  final service = ref.read(databaseServiceProvider);
  return [
    for (final entry in service.allEntries)
      if (!service.isInRecycleBin(entry) && isFavoriteEntry(entry)) entry,
  ];
});

/// Whether the explorer is showing the dedicated favorites view (instead of
/// the current group's entries). Toggled by the star icon button on desktop
/// (sidebar) and mobile (entries app bar).
final favoritesViewProvider = StateProvider<bool>((ref) => false);
