import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../overlay/overlay_cubit.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_cubit.dart';
import '../../tracking/cubit/tracking_cubit.dart';
import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';
import 'bani_drawer.dart';
import 'controls_pane.dart';
import 'display_pane.dart';
import 'favorites_pane.dart';
import 'history_pane.dart';
import 'presenter_keyboard.dart';
import 'search_pane.dart';
import 'settings_screen.dart';
import 'shabad_view.dart';

/// Projected background presets, one place for the in-app colour and the CSS
/// hex the LAN overlay uses.
const _bgColors = <DisplayBg, Color>{
  DisplayBg.navy: AppColors.navy,
  DisplayBg.black: Colors.black,
  DisplayBg.graphite: Color(0xFF14161A),
  DisplayBg.midnight: AppColors.navyDeep,
};
const _bgHexes = <DisplayBg, String>{
  DisplayBg.navy: '#0B1E3B',
  DisplayBg.black: '#000000',
  DisplayBg.graphite: '#14161A',
  DisplayBg.midnight: '#071426',
};

/// A CSS hex string for the overlay, from a Flutter [Color].
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Mirror the shown line to the LAN overlay, following the Light/Dark display
/// theme (STTM's Colors): light = parchment surface + navy text; dark = the
/// selected background preset + cream text. Called on line change and on a
/// theme flip.
void _pushOverlay(BuildContext context, PresenterState s) {
  final light = Theme.of(context).brightness == Brightness.light;
  final g = context.gurbani;
  // Quick-insert slides (id 'special') size by the Announcements scale.
  final special = s.line?.id == 'special';
  context.read<OverlayCubit>().showLine(
    gurmukhi: s.line?.gurmukhi ?? '',
    background: light ? _hex(g.displayBackground) : _bgHexes[s.displayBg]!,
    english: s.display.translations['en'],
    punjabi: s.display.translations['pa'],
    roman: switch (s.display.transliterations['roman']) {
      final r? => strippedGurmukhi(r),
      _ => null,
    },
    larivaar: s.larivaar,
    vishraam: s.vishraam,
    fontScale: special ? s.announcementScale : s.fontScale,
    translationScale: s.translationScale,
    teekaScale: s.teekaScale,
    translitScale: s.translitScale,
    text: _hex(g.displayText),
    accent: _hex(g.displayAccent),
  );
}

/// The presenter: four panes wired to one shown line. A [BlocListener] bridges
/// the AI tracker to the presenter, so a line the tracker finds flows into the
/// same display the operator drives by hand. [PresenterKeyboard] adds arrow /
/// space / page / home / end / esc control over the shown line.
class PresenterView extends StatelessWidget {
  const PresenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final presenter = context.read<PresenterCubit>();
    return MultiBlocListener(
      listeners: [
        // The AI tracker's line flows into the same display the operator drives.
        BlocListener<TrackingCubit, TrackingState>(
          listenWhen: (a, b) => a.verse?.id != b.verse?.id,
          listener: (context, t) {
            if (t.verse != null) presenter.showTrackerVerse(t.verse!);
          },
        ),
        // Mirror the shown line to the LAN overlay (projector / OBS).
        BlocListener<PresenterCubit, PresenterState>(
          listenWhen: (a, b) =>
              a.current != b.current ||
              a.shabad != b.shabad ||
              a.displayBg != b.displayBg ||
              a.larivaar != b.larivaar ||
              a.vishraam != b.vishraam ||
              a.fontScale != b.fontScale ||
              a.translationScale != b.translationScale ||
              a.teekaScale != b.teekaScale ||
              a.translitScale != b.translitScale,
          listener: (context, s) => _pushOverlay(context, s),
        ),
        // Flipping the Light/Dark theme repaints the projector too, not just
        // on the next line change.
        BlocListener<ThemeCubit, ThemeMode>(
          listener: (context, _) => _pushOverlay(context, presenter.state),
        ),
      ],
      child: PresenterKeyboard(
        child: Scaffold(
          drawer: const BaniDrawer(),
          // No AppBar: a 40px icon rail (STTM's header rail) carries the two
          // drawer openers, and every other pixel is operator content.
          body: Row(
            children: [
              const _IconRail(),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 720;
                    // Full-bleed panes split by 1px seams - a console, not a
                    // card feed.
                    final left = Column(
                      children: [
                        Expanded(child: _Pane(child: const SearchPane())),
                        const Divider(height: 1, thickness: 1),
                        Expanded(
                          child: _Pane(
                            padding: EdgeInsets.zero,
                            child: const ShabadView(),
                          ),
                        ),
                      ],
                    );
                    final right = Column(
                      children: [
                        const Expanded(flex: 3, child: _DisplayPaneHost()),
                        const Divider(height: 1, thickness: 1),
                        Expanded(
                          flex: 2,
                          child: _Pane(
                            padding: EdgeInsets.zero,
                            child: const _ControlsTabs(),
                          ),
                        ),
                      ],
                    );
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(child: left),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(child: right),
                        ],
                      );
                    }
                    // Narrow (phone): a scroll of fixed-height sections - the
                    // panes have inner ListViews, so they need bounded heights,
                    // and scrolling means a short window can never overflow.
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 200,
                            child: _DisplayPaneHost(),
                          ),
                          SizedBox(
                            height: 360,
                            child: _Pane(child: const SearchPane()),
                          ),
                          SizedBox(
                            height: 300,
                            child: _Pane(
                              padding: EdgeInsets.zero,
                              child: const ShabadView(),
                            ),
                          ),
                          SizedBox(
                            height: 440,
                            child: _Pane(
                              padding: EdgeInsets.zero,
                              child: const _ControlsTabs(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// STTM's 40px left rail: banis on top, settings pinned to the bottom.
class _IconRail extends StatelessWidget {
  const _IconRail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          const SizedBox(height: 4),
          Builder(
            builder: (context) => IconButton(
              key: const Key('rail_banis'),
              icon: const Icon(Icons.menu_book, size: 19),
              tooltip: 'Banis',
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const Spacer(),
          Builder(
            builder: (context) => IconButton(
              key: const Key('rail_settings'),
              icon: const Icon(Icons.tune, size: 19),
              tooltip: 'Settings',
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => _openSettings(context),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// The projected display, fed by the current line + selected background.
/// Push STTM's full-screen settings, carrying the presenter cubits + theme
/// controller into the new route (a route sits under a fresh Navigator, so the
/// providers must be threaded explicitly).
void _openSettings(BuildContext context) {
  final presenter = context.read<PresenterCubit>();
  final overlay = context.read<OverlayCubit>();
  final theme = context.read<ThemeCubit>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: presenter),
          BlocProvider.value(value: overlay),
          BlocProvider.value(value: theme),
        ],
        child: const SettingsScreen(),
      ),
    ),
  );
}

/// A small live preview of the projected display (the current line), for the
/// Settings screen's preview panel. Reuses the same [DisplayPane] path.
class DisplayPreview extends StatelessWidget {
  const DisplayPreview({super.key});

  @override
  Widget build(BuildContext context) => const ClipRRect(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    // Render the display at a fixed 16:9 logical size and scale it into the
    // small preview box, so the full-size slide never overflows the panel.
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: 960, height: 540, child: _DisplayPaneHost()),
    ),
  );
}

class _DisplayPaneHost extends StatelessWidget {
  const _DisplayPaneHost();

  @override
  Widget build(BuildContext context) {
    // Full-bleed: the preview IS its quadrant, like STTM - no floating card.
    return SizedBox.expand(
      child: BlocBuilder<PresenterCubit, PresenterState>(
        buildWhen: (a, b) =>
            a.current != b.current ||
            a.shabad != b.shabad ||
            a.displayBg != b.displayBg ||
            a.larivaar != b.larivaar ||
            a.vishraam != b.vishraam ||
            a.fontScale != b.fontScale ||
            a.leftAlign != b.leftAlign ||
            a.slideTransitions != b.slideTransitions ||
            a.translationScale != b.translationScale ||
            a.teekaScale != b.teekaScale ||
            a.translitScale != b.translitScale ||
            a.announcementScale != b.announcementScale,
        builder: (context, state) {
          // Light theme = parchment surface (from the GurbaniTheme tokens);
          // dark theme = the selected background preset.
          final light = Theme.of(context).brightness == Brightness.light;
          final bg = light
              ? context.gurbani.displayBackground
              : _bgColors[state.displayBg]!;
          final line = state.line;
          final Widget child;
          if (line == null) {
            child = ColoredBox(
              key: const ValueKey('empty'),
              color: bg,
              child: Center(
                child: Text(
                  'ੴ',
                  style: TextStyle(
                    fontFamily: kGurmukhiFont,
                    fontSize: 64,
                    color: context.gurbani.displayText.withValues(alpha: 0.35),
                  ),
                ),
              ),
            );
          } else {
            child = DisplayPane(
              key: ValueKey(line.id),
              gurmukhi: line.gurmukhi,
              display: state.display,
              background: bg,
              larivaar: state.larivaar,
              vishraam: state.vishraam,
              // Quick-insert slides size by the Announcements scale.
              fontScale: line.id == 'special'
                  ? state.announcementScale
                  : state.fontScale,
              leftAlign: state.leftAlign,
              translationScale: state.translationScale,
              teekaScale: state.teekaScale,
              translitScale: state.translitScale,
            );
          }
          // STTM's Slide Transitions: cross-fade the projected line on change.
          return AnimatedSwitcher(
            duration: Duration(milliseconds: state.slideTransitions ? 240 : 0),
            child: child,
          );
        },
      ),
    );
  }
}

/// Bottom-right: the operator controls and the session history, tabbed like
/// STTM. History gets its own tab so the quick-insert slides and recent shabads
/// aren't buried under the display settings.
class _ControlsTabs extends StatelessWidget {
  const _ControlsTabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'History'),
              Tab(text: 'Favorites'),
              Tab(text: 'Controls'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: HistoryPane(),
                ),
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: FavoritesPane(),
                ),
                const SingleChildScrollView(
                  padding: EdgeInsets.all(14),
                  child: ControlsPane(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-bleed pane: luminance separates regions (with the 1px seams in the
/// shell); no margins, no rounded card - console, not feed.
class _Pane extends StatelessWidget {
  const _Pane({required this.child, this.padding = const EdgeInsets.all(10)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(padding: padding, child: child),
    );
  }
}
