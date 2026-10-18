import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';

/// History + Quick Insert (STTM's bottom-right). The list is what you've shown
/// this session, most recent first, tap to jump back. The footer drops in the
/// standard slides without a search; its disclosure header collapses it when
/// the history needs the room (STTM's arrow).
class HistoryPane extends StatefulWidget {
  const HistoryPane({super.key});

  @override
  State<HistoryPane> createState() => _HistoryPaneState();
}

class _HistoryPaneState extends State<HistoryPane> {
  bool _quickInsertOpen = true;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PresenterCubit>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child:
              BlocSelector<
                PresenterCubit,
                PresenterState,
                (List<HistoryEntry>, bool)
              >(
                selector: (s) => (s.history, s.historyNewestFirst),
                builder: (context, data) {
                  final (history, newestFirst) = data;
                  if (history.isEmpty) {
                    return Center(
                      child: Text(
                        'Shabads you show appear here',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  // Storage is newest-first; oldest-first just reverses the view.
                  final ordered = newestFirst
                      ? history
                      : history.reversed.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: ordered.length,
                    itemBuilder: (context, i) => _HistoryTile(
                      entry: ordered[i],
                      onTap: () => cubit.openHistory(ordered[i]),
                      onDelete: () => cubit.deleteHistoryEntry(ordered[i]),
                    ),
                  );
                },
              ),
        ),
        const Divider(height: 10),
        Row(
          children: [
            Expanded(
              child: InkWell(
                mouseCursor: kClickCursor,
                onTap: () =>
                    setState(() => _quickInsertOpen = !_quickInsertOpen),
                child: Row(
                  children: [
                    Icon(
                      _quickInsertOpen
                          ? Icons.arrow_drop_down
                          : Icons.arrow_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      'QUICK INSERT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // STTM's history controls, on the same strip: order toggle + Clear.
            BlocSelector<PresenterCubit, PresenterState, (bool, bool)>(
              selector: (s) => (s.history.isNotEmpty, s.historyNewestFirst),
              builder: (context, data) {
                final (hasHistory, newestFirst) = data;
                if (!hasHistory) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: cubit.toggleHistoryOrder,
                      icon: const Icon(Icons.swap_vert, size: 16),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      color: theme.colorScheme.onSurfaceVariant,
                      tooltip: newestFirst
                          ? 'Newest first (tap for oldest)'
                          : 'Oldest first (tap for newest)',
                    ),
                    TextButton.icon(
                      onPressed: cubit.clearHistory,
                      icon: const Icon(Icons.delete_sweep, size: 14),
                      label: const Text('Clear history'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        // Natural height, never flexed - a Flexible here would flex-share the
        // column's leftover space with the history Expanded and pin dead space
        // under the chips. One row that scrolls sideways when the pane is
        // narrow keeps the footer ~40px tall in every window.
        if (_quickInsertOpen)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                spacing: 6,
                children: [
                  _QuickChip(label: 'Waheguru', onTap: cubit.showWaheguru),
                  _QuickChip(label: 'Mool Mantar', onTap: cubit.showMoolMantar),
                  _QuickChip(
                    label: 'Anand Sahib Bhog',
                    icon: Icons.auto_stories,
                    onTap: cubit.showAnandBhog,
                  ),
                  _QuickChip(
                    label: 'Announcement',
                    icon: Icons.campaign,
                    onTap: () => _announce(context, cubit),
                  ),
                  _QuickChip(
                    label: 'Blank',
                    icon: Icons.crop_square,
                    onTap: cubit.showBlank,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Prompt for announcement text, then show it as a slide.
  Future<void> _announce(BuildContext context, PresenterCubit cubit) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Announcement'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'Text to show on the display',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Show'),
          ),
        ],
      ),
    );
    if (text != null && text.trim().isNotEmpty) {
      cubit.showAnnouncement(text.trim());
    }
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final g = context.gurbani;
    final theme = Theme.of(context);
    final meta = [
      entry.author,
      entry.section,
      if (entry.page > 0) 'Ang ${entry.page}',
    ].where((s) => s.isNotEmpty).join('  ·  ');
    // Ink, not Container: an opaque Container hides the InkWell's hover and
    // splash; Ink paints the fill into the Material's ink layer instead.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        mouseCursor: kClickCursor,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
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
                      // List-size Gurmukhi: the display pane owns the big type.
                      style: g.gurmukhi.copyWith(fontSize: 18, height: 1.4),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Per-item delete (STTM). Muted until hovered - the IconButton's
              // own hover confirms it - and its tap never opens the shabad.
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close, size: 15),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: 'Remove from history',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon ?? Icons.add, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
