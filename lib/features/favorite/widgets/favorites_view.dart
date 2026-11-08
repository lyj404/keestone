import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/entry_list_tile.dart';
import '../../database/providers/database_provider.dart';
import '../../favorite/data/favorite_service.dart';

/// Dedicated favorites view, shown in place of the group entry list when the
/// user toggles the star icon button (desktop sidebar / mobile app bar).
/// Lists every favorited entry vault-wide with its group path.
class FavoritesView extends ConsumerWidget {
  final KdbxEntry? selectedEntry;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry> onToggleFavoriteEntry;
  final bool mobileStyle;

  const FavoritesView({
    super.key,
    this.selectedEntry,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    required this.onToggleFavoriteEntry,
    this.mobileStyle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favorites = ref.watch(favoritesProvider);

    if (favorites.isEmpty) {
      return EmptyState(icon: Icons.star_outline_rounded, message: l10n.noFavorites);
    }

    final service = ref.read(databaseServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            mobileStyle ? 20 : 16,
            12,
            16,
            8,
          ),
          child: Text(
            '${favorites.length} ${l10n.favorites}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: ListView.builder(
            addAutomaticKeepAlives: false,
            scrollCacheExtent: const ScrollCacheExtent.pixels(200),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: favorites.length + 1,
            itemBuilder: (context, index) {
              if (index == favorites.length) return const SizedBox(height: 80);
              final entry = favorites[index];
              return RepaintBoundary(
                child: EntryListTile(
                  key: ValueKey(entry.uuid),
                  entry: entry,
                  mobileStyle: mobileStyle,
                  isSelected: entry == selectedEntry,
                  onTap: () => onEntrySelect(entry),
                  onOpen: () => onEntryOpen(entry),
                  onDelete: () => onDeleteEntry(entry),
                  onToggleFavorite: () => onToggleFavoriteEntry(entry),
                  query: null,
                  // Help disambiguate same-named entries across groups.
                  subtitle: entry.parent == null
                      ? null
                      : service.getGroupPath(entry.parent!),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
