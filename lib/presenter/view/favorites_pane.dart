import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';

/// Saved shabads (STTM's Favorites), stored locally. Tap to reopen, unstar to
/// remove. Star a shabad from the shabad pane's toolbar.
class FavoritesPane extends StatelessWidget {
  const FavoritesPane({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PresenterCubit>();
    final theme = Theme.of(context);
    return BlocSelector<PresenterCubit, PresenterState, List<HistoryEntry>>(
      selector: (s) => s.favorites,
      builder: (context, favorites) {
        if (favorites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Star a shabad (☆ on the shabad pane) to save it here',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: favorites.length,
          itemBuilder: (context, i) => _FavoriteTile(
            entry: favorites[i],
            onTap: () => cubit.openFavorite(favorites[i]),
            onRemove: () => cubit.removeFavorite(favorites[i]),
          ),
        );
      },
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final g = context.gurbani;
    final theme = Theme.of(context);
    final meta = [
      entry.author,
      entry.section,
      if (entry.page > 0) 'Ang ${entry.page}',
    ].where((s) => s.isNotEmpty).join('  ·  ');
    // Ink, not Container: an opaque Container hides the InkWell's hover.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        mouseCursor: kClickCursor,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: g.accent, width: 3)),
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strippedGurmukhi(entry.gurmukhi),
                      // List-size Gurmukhi, like the history tiles.
                      style: g.gurmukhi.copyWith(fontSize: 18, height: 1.4),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.star, size: 18, color: g.accent),
                tooltip: 'Remove from favorites',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
