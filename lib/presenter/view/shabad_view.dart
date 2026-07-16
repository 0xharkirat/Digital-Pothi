import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../engine/corpus.dart';
import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';

/// Bottom-left pane: a small nav toolbar (line + shabad) over the shown shabad's
/// lines, the current one highlighted, tap to display a line. A positioned list
/// so it can scroll to *any* line - including one a search jumped to - but only
/// when it isn't already on screen.
class ShabadView extends StatefulWidget {
  const ShabadView({super.key});

  @override
  State<ShabadView> createState() => _ShabadViewState();
}

class _ShabadViewState extends State<ShabadView> {
  final _controller = ItemScrollController();
  final _positions = ItemPositionsListener.create();

  void _scrollTo(int index, int count) {
    // Nothing to scroll for a single line, and never scroll before layout.
    if (index < 0 || count <= 1 || !_controller.isAttached) return;
    // Skip if the line is already comfortably on screen - no jarring re-centre
    // when you tap a visible line, or the tracker nudges within the viewport.
    final here = _positions.itemPositions.value.where((p) => p.index == index);
    if (here.isNotEmpty) {
      final p = here.first;
      if (p.itemLeadingEdge >= 0 && p.itemTrailingEdge <= 1) return;
    }
    // 0.35 keeps a little context above; the list clamps at its ends, so a line
    // with nothing above/below sits at the edge instead of leaving a gap.
    _controller.scrollTo(
      index: index,
      alignment: 0.35,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PresenterCubit>();
    return BlocConsumer<PresenterCubit, PresenterState>(
      listenWhen: (a, b) => a.current != b.current || a.shabad != b.shabad,
      listener: (_, s) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollTo(s.current, s.shabad.length),
      ),
      buildWhen: (a, b) =>
          a.shabad != b.shabad ||
          a.current != b.current ||
          a.following != b.following ||
          a.homeIndex != b.homeIndex,
      builder: (context, state) {
        if (state.shabad.isEmpty) {
          return Center(
            child: Text(
              'Select a shabad to see its lines',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: [
            _ShabadToolbar(state: state, cubit: cubit),
            const Divider(height: 1),
            Expanded(
              child: ScrollablePositionedList.builder(
                itemScrollController: _controller,
                itemPositionsListener: _positions,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.shabad.length,
                itemBuilder: (context, i) => _LineRow(
                  verse: state.shabad[i],
                  selected: i == state.current,
                  following: i == state.current && state.following,
                  // Home only exists for corpus shabads (homeIndex == -1 for
                  // banis and quick-inserts hides the affordance entirely).
                  isHome: state.homeIndex != -1 && i == state.homeIndex,
                  onSetHome: state.homeIndex != -1
                      ? () => cubit.setHome(i)
                      : null,
                  onTap: () => cubit.showLine(i),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Line + shabad navigation, on the shabad pane itself (next to the lines).
class _ShabadToolbar extends StatelessWidget {
  const _ShabadToolbar({required this.state, required this.cubit});
  final PresenterState state;
  final PresenterCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: state.hasPrev ? cubit.prevLine : null,
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Previous line',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            onPressed: state.hasNext ? cubit.nextLine : null,
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Next line',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: state.canFavorite ? cubit.toggleFavorite : null,
            icon: Icon(
              state.isFavorite ? Icons.star : Icons.star_border,
              size: 20,
              color: state.isFavorite ? context.gurbani.accent : null,
            ),
            tooltip: state.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: cubit.prevShabad,
            icon: const Icon(Icons.skip_previous, size: 18),
            label: const Text('Prev'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton.icon(
            onPressed: cubit.nextShabad,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Next'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatefulWidget {
  const _LineRow({
    required this.verse,
    required this.selected,
    required this.following,
    required this.isHome,
    required this.onSetHome,
    required this.onTap,
  });

  final Verse verse;
  final bool selected;
  final bool following;
  final bool isHome;
  final VoidCallback? onSetHome;
  final VoidCallback onTap;

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
  bool _hovered = false;

  Verse get verse => widget.verse;
  bool get selected => widget.selected;
  bool get following => widget.following;
  bool get isHome => widget.isHome;
  VoidCallback? get onSetHome => widget.onSetHome;

  @override
  Widget build(BuildContext context) {
    final g = context.gurbani;
    final theme = Theme.of(context);
    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _hovered = h),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? g.accent.withValues(alpha: 0.14) : null,
          border: Border(
            left: BorderSide(
              color: selected ? g.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                strippedGurmukhi(verse.gurmukhi),
                style: g.gurmukhi.copyWith(
                  color: selected ? g.accent : g.gurmukhi.color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (verse.isRahao)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: g.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ਰਹਾਉ',
                  style: g.gurmukhi.copyWith(fontSize: 12, color: g.accent),
                ),
              ),
            if (following)
              Icon(Icons.graphic_eq, size: 16, color: g.accent)
            else if (selected)
              Icon(Icons.check, size: 16, color: g.accent),
            // Hover-reveal like STTM: the filled home stays put; the "set
            // home here" affordance appears only under the pointer, so a
            // shabad isn't a column of idle icons.
            if (onSetHome != null && (isHome || _hovered))
              IconButton(
                onPressed: onSetHome,
                icon: Icon(isHome ? Icons.home : Icons.home_outlined),
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                tooltip: isHome ? 'Home line' : 'Set home line',
                color: isHome
                    ? g.accent
                    : theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.55,
                      ),
              )
            else if (onSetHome != null)
              // Keep the row height stable when the icon pops in.
              const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
