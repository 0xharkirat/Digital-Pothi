import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../overlay/overlay_cubit.dart';
import '../../theme/app_theme.dart';
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
import 'settings_drawer.dart';
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
              a.fontScale != b.fontScale,
          listener: (context, s) => context.read<OverlayCubit>().showLine(
            gurmukhi: s.line?.gurmukhi ?? '',
            background: _bgHexes[s.displayBg]!,
            english: s.display.translations['en'],
            punjabi: s.display.translations['pa'],
            roman: switch (s.display.transliterations['roman']) {
              final r? => strippedGurmukhi(r),
              _ => null,
            },
            larivaar: s.larivaar,
            vishraam: s.vishraam,
            fontScale: s.fontScale,
          ),
        ),
      ],
      child: PresenterKeyboard(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Gurbani Live'),
            centerTitle: true,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_book),
                tooltip: 'Banis',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Settings',
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          drawer: const BaniDrawer(),
          endDrawer: const SettingsDrawer(),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 720;
              final left = Column(
                children: [
                  Expanded(child: _Pane(child: const SearchPane())),
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
                    Expanded(child: right),
                  ],
                );
              }
              // Narrow (phone): a scroll of fixed-height sections - the panes have
              // inner ListViews, so they need bounded heights, and scrolling means
              // a short window can never overflow.
              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 200, child: _DisplayPaneHost()),
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
      ),
    );
  }
}

/// The projected display, fed by the current line + selected background.
class _DisplayPaneHost extends StatelessWidget {
  const _DisplayPaneHost();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: BlocBuilder<PresenterCubit, PresenterState>(
        buildWhen: (a, b) =>
            a.current != b.current ||
            a.shabad != b.shabad ||
            a.displayBg != b.displayBg ||
            a.larivaar != b.larivaar ||
            a.vishraam != b.vishraam ||
            a.fontScale != b.fontScale,
        builder: (context, state) {
          final bg = _bgColors[state.displayBg]!;
          final line = state.line;
          if (line == null) {
            return ColoredBox(
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
          }
          return DisplayPane(
            gurmukhi: line.gurmukhi,
            display: state.display,
            background: bg,
            larivaar: state.larivaar,
            vishraam: state.vishraam,
            fontScale: state.fontScale,
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

class _Pane extends StatelessWidget {
  const _Pane({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
