import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart' show BaniLength;
import '../../theme/app_theme.dart';
import '../../theme/theme_cubit.dart';
import '../cubit/presenter_cubit.dart';
import 'presenter_view.dart' show DisplayPreview;
import 'overlay_control.dart' show OverlayControl;

/// STTM's full-screen Settings, ported to our stack (configs/user-settings.json
/// is the structure of record). Left nav scrolls the centre column; the right
/// column is a live Preview over the Colors + Backgrounds pickers. Controls
/// backed by our state are live; those that need a not-yet-built feature render
/// in their exact STTM slot, disabled, tagged "Soon", so the layout stays
/// faithful and nothing pretends to work.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scroll = ScrollController();
  final _slideLayout = GlobalKey();
  final _baniLangs = GlobalKey();
  final _appSettings = GlobalKey();
  String _active = 'slide-layout';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jump(String id, GlobalKey key) {
    setState(() => _active = id);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Left: STTM's settings-nav (scroll-to headings).
            _SettingsNav(
              active: _active,
              onTap: {
                'slide-layout': () => _jump('slide-layout', _slideLayout),
                'bani-and-languages': () =>
                    _jump('bani-and-languages', _baniLangs),
                'app-settings': () => _jump('app-settings', _appSettings),
              },
            ),
            const VerticalDivider(width: 1, thickness: 1),
            // Centre: the settings columns.
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: BlocBuilder<PresenterCubit, PresenterState>(
                  builder: (context, state) => _SettingsBody(
                    state: state,
                    slideLayoutKey: _slideLayout,
                    baniLangsKey: _baniLangs,
                    appSettingsKey: _appSettings,
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            // Right: preview + colors + backgrounds (STTM's other-settings).
            const Expanded(flex: 2, child: _PreviewPanel()),
          ],
        ),
      ),
      // STTM closes the overlay with the top-right X.
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'settings-close',
        tooltip: 'Close settings',
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Icon(Icons.close),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}

class _SettingsNav extends StatelessWidget {
  const _SettingsNav({required this.active, required this.onTap});
  final String active;
  final Map<String, VoidCallback> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const items = {
      'slide-layout': 'Slide Layout',
      'bani-and-languages': 'Bani & Languages',
      'app-settings': 'App Settings',
    };
    return SizedBox(
      width: 190,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          for (final e in items.entries)
            InkWell(
              mouseCursor: kClickCursor,
              onTap: onTap[e.key],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: active == e.key
                    ? theme.colorScheme.surfaceContainerHigh
                    : null,
                child: Text(
                  e.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: active == e.key
                        ? context.gurbani.accent
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: active == e.key
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.state,
    required this.slideLayoutKey,
    required this.baniLangsKey,
    required this.appSettingsKey,
  });

  final PresenterState state;
  final GlobalKey slideLayoutKey;
  final GlobalKey baniLangsKey;
  final GlobalKey appSettingsKey;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PresenterCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- SLIDE LAYOUT ----
        _Heading('SLIDE LAYOUT', key: slideLayoutKey),
        const _SubHeading('FONT SIZES'),
        _RangeRow(
          label: 'Bani',
          value: state.fontScale,
          min: 0.7,
          max: 1.5,
          onChanged: cubit.setFontScale,
        ),
        const _SoonRow('Translation'),
        const _SoonRow('Teeka'),
        const _SoonRow('Transliteration'),
        const _SoonRow('Announcements'),
        _ButtonRow(
          label: 'Reset Font Sizes',
          button: 'Reset',
          onPressed: () => cubit.setFontScale(1),
        ),
        const _SubHeading('DISPLAY OPTIONS'),
        const _SoonSwitch('Akhand Paatth View'),
        const _SoonSwitch('Next Line'),
        _SwitchRow(
          label: 'Left-Align',
          value: state.leftAlign,
          onChanged: (_) => cubit.toggleLeftAlign(),
        ),
        _SwitchRow(
          label: 'Larivaar',
          value: state.larivaar,
          onChanged: (_) => cubit.toggleLarivaar(),
        ),
        const _SoonSwitch('Larivaar Assist'),
        _SwitchRow(
          label: 'Show Vishraams',
          value: state.vishraam,
          onChanged: (_) => cubit.toggleVishraam(),
        ),
        const _SoonRow('Vishraam Source'),
        _SwitchRow(
          label: 'Slide Transitions',
          value: state.slideTransitions,
          onChanged: (_) => cubit.toggleSlideTransitions(),
        ),
        const _SubHeading('AUTOPLAY OPTIONS'),
        const _SoonSwitch('Auto Play'),

        // ---- BANI & LANGUAGES ----
        const SizedBox(height: 8),
        _Heading('BANI & LANGUAGES', key: baniLangsKey),
        const _SubHeading('BANI SETTINGS'),
        _DropdownRow<BaniLength>(
          label: 'Bani Length',
          value: state.baniLength,
          items: const {
            BaniLength.short: 'Short',
            BaniLength.medium: 'Medium',
            BaniLength.long: 'Long',
            BaniLength.extralong: 'Extra Long',
          },
          onChanged: cubit.setBaniLength,
        ),
        const _SubHeading('LANGUAGE SETTINGS'),
        // We bundle exactly these sources today; the dropdowns show the real
        // choice honestly rather than inventing BaniDB/Manmohan/Faridkot.
        const _DropdownRow<int>(
          label: 'Teeka Source',
          value: 0,
          items: {0: 'Prof. Sahib Singh'},
          onChanged: null,
        ),
        const _DropdownRow<int>(
          label: 'Translation Source (English)',
          value: 0,
          items: {0: 'Dr. Sant Singh Khalsa'},
          onChanged: null,
        ),
        _SwitchRow(
          label: 'Bani names in English',
          value: state.englishBaniNames,
          onChanged: (_) => cubit.toggleBaniNames(),
        ),

        // ---- APP SETTINGS ----
        const SizedBox(height: 8),
        _Heading('APP SETTINGS', key: appSettingsKey),
        const _SubHeading('APP'),
        _SwitchRow(
          label: 'Intelligent Spacebar',
          value: state.intelligentSpacebar,
          onChanged: (_) => cubit.toggleIntelligentSpacebar(),
        ),
        const _SoonSwitch('Live Feed Text Files'),
        const _SubHeading('PROJECTOR / OVERLAY'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: OverlayControl(),
        ),
      ],
    );
  }
}

// ---- The right panel: live preview + colors + backgrounds ----

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeCtl = context.read<ThemeCubit>();
    final cubit = context.read<PresenterCubit>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Preview', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        const AspectRatio(aspectRatio: 16 / 9, child: DisplayPreview()),
        const SizedBox(height: 20),
        const _SubHeading('COLORS'),
        BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, mode) => Row(
            children: [
              Expanded(
                child: _ColorTile(
                  label: 'Light',
                  selected: mode == ThemeMode.light,
                  background: Colors.white,
                  foreground: Colors.black,
                  onTap: () => themeCtl.setLight(light: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ColorTile(
                  label: 'Dark',
                  selected: mode == ThemeMode.dark,
                  background: const Color(0xFF15171C),
                  foreground: Colors.white,
                  onTap: () => themeCtl.setLight(light: false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SubHeading('BACKGROUNDS'),
        const SizedBox(height: 8),
        BlocBuilder<PresenterCubit, PresenterState>(
          buildWhen: (a, b) => a.displayBg != b.displayBg,
          builder: (context, state) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in const {
                DisplayBg.navy: ('Navy', AppColors.navy),
                DisplayBg.midnight: ('Midnight', AppColors.navyDeep),
                DisplayBg.graphite: ('Graphite', Color(0xFF14161A)),
                DisplayBg.black: ('Black', Colors.black),
              }.entries)
                _BgTile(
                  label: e.value.$1,
                  color: e.value.$2,
                  selected: state.displayBg == e.key,
                  onTap: () => cubit.setDisplayBg(e.key),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _SoonNote(
          'Image & video backgrounds (Khalsa Gold, Baagi Blue, ...) coming with '
          'A3.',
          theme,
        ),
      ],
    );
  }
}

// ---- Small STTM-styled row widgets ----

class _Heading extends StatelessWidget {
  const _Heading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleLarge?.copyWith(
          color: context.gurbani.accent,
        ),
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Switch(value: value, onChanged: onChanged, mouseCursor: kClickCursor),
        ],
      ),
    );
  }
}

/// A switch in its correct STTM slot, disabled and tagged - the feature isn't
/// built yet, so it renders in place but does nothing.
class _SoonSwitch extends StatelessWidget {
  const _SoonSwitch(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: _SoonLabel(label)),
        const Switch(value: false, onChanged: null),
      ],
    ),
  );
}

class _SoonRow extends StatelessWidget {
  const _SoonRow(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: _SoonLabel(label),
  );
}

class _SoonLabel extends StatelessWidget {
  const _SoonLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Soon',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${(value * 100).round()}%',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(8),
            onChanged: onChanged == null
                ? null
                : (v) {
                    if (v != null) onChanged!(v);
                  },
            items: [
              for (final e in items.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.label,
    required this.button,
    required this.onPressed,
  });
  final String label;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(button),
          ),
        ],
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.label,
    required this.selected,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: kClickCursor,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? context.gurbani.accent : Colors.transparent,
            width: 2.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BgTile extends StatelessWidget {
  const _BgTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: kClickCursor,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 96,
        height: 54,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? context.gurbani.accent
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.cream, fontSize: 12),
        ),
      ),
    );
  }
}

class _SoonNote extends StatelessWidget {
  const _SoonNote(this.text, this.theme);
  final String text;
  final ThemeData theme;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    ),
  );
}
