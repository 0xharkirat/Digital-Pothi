import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart';
import '../../overlay/overlay_cubit.dart';
import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';

/// The content each output renders, chosen with the overlay URL's `?show=`
/// param. Minimal = just the shabad + Punjabi teeka; full = everything.
const _showMinimal = 'gurmukhi,punjabi';
const _showFull = 'gurmukhi,punjabi,english,roman';

bool get _isDesktopHost =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// The settings panel (an end-drawer opened from the app bar gear), like STTM's
/// settings screen: display options + backgrounds + the projector / overlay
/// controls, kept out of the everyday operator panes.
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final presenter = context.read<PresenterCubit>();
    final theme = Theme.of(context);
    return Drawer(
      width: 340,
      child: SafeArea(
        child: BlocBuilder<PresenterCubit, PresenterState>(
          buildWhen: (a, b) =>
              a.larivaar != b.larivaar ||
              a.vishraam != b.vishraam ||
              a.fontScale != b.fontScale ||
              a.displayBg != b.displayBg ||
              a.baniLength != b.baniLength,
          builder: (context, state) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text('Settings', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel('DISPLAY'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Toggle(
                    label: 'Larivaar',
                    on: state.larivaar,
                    onTap: presenter.toggleLarivaar,
                  ),
                  _Toggle(
                    label: 'Vishraam',
                    on: state.vishraam,
                    onTap: presenter.toggleVishraam,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Font size', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  IconButton.outlined(
                    onPressed: () => presenter.bumpFontScale(-0.1),
                    icon: const Icon(Icons.text_decrease, size: 18),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(state.fontScale * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: () => presenter.bumpFontScale(0.1),
                    icon: const Icon(Icons.text_increase, size: 18),
                  ),
                ],
              ),
              const Divider(height: 32),
              const _SectionLabel('BANI LENGTH'),
              const SizedBox(height: 4),
              Text(
                'For Rehras, Sohila, Chaupai, Aarti.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in const {
                    BaniLength.short: 'Short',
                    BaniLength.medium: 'Medium',
                    BaniLength.long: 'Long',
                    BaniLength.extralong: 'Extra Long',
                  }.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: state.baniLength == e.key,
                      onSelected: (_) => presenter.setBaniLength(e.key),
                    ),
                ],
              ),
              const Divider(height: 32),
              const _SectionLabel('DISPLAY BACKGROUND'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in const {
                    DisplayBg.navy: AppColors.navy,
                    DisplayBg.midnight: AppColors.navyDeep,
                    DisplayBg.graphite: Color(0xFF14161A),
                    DisplayBg.black: Colors.black,
                  }.entries)
                    _BgSwatch(
                      color: entry.value,
                      selected: state.displayBg == entry.key,
                      onTap: () => presenter.setDisplayBg(entry.key),
                    ),
                ],
              ),
              const Divider(height: 32),
              const _SectionLabel('PROJECTOR / OVERLAY'),
              const SizedBox(height: 8),
              const _OverlayControl(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// A pill toggle for a display option (larivaar / vishraam).
class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.gurbani.accent;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.18) : null,
          border: Border.all(color: on ? accent : theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check : Icons.remove,
              size: 15,
              color: on ? accent : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: on ? accent : theme.colorScheme.onSurfaceVariant,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BgSwatch extends StatelessWidget {
  const _BgSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.gurbani.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent : Theme.of(context).colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

/// Start/stop the LAN overlay, open the native fullscreen output window, and
/// offer ready-made links - each showing a different subset of the content.
class _OverlayControl extends StatelessWidget {
  const _OverlayControl();

  @override
  Widget build(BuildContext context) {
    final overlay = context.read<OverlayCubit>();
    final theme = Theme.of(context);
    return BlocBuilder<OverlayCubit, OverlayStatus>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: overlay.toggle,
            icon: Icon(state.running ? Icons.stop_circle : Icons.cast),
            label: Text(state.running ? 'Stop overlay' : 'Start overlay'),
          ),
          if (state.running) ...[
            if (_isDesktopHost) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: state.outputOpen
                    ? overlay.closeOutput
                    : () => overlay.openOutput('${state.url}/?show=$_showFull'),
                icon: Icon(
                  state.outputOpen
                      ? Icons.close_fullscreen
                      : Icons.open_in_full,
                ),
                label: Text(
                  state.outputOpen
                      ? 'Close output window'
                      : 'Open output window',
                ),
              ),
            ],
            const SizedBox(height: 12),
            _OverlayLink(
              label: 'Shabad + Punjabi',
              url: '${state.url}/?show=$_showMinimal',
            ),
            _OverlayLink(
              label: 'Everything',
              url: '${state.url}/?show=$_showFull',
            ),
            const SizedBox(height: 4),
            Text(
              'Open a link full-screen on the projector (F11), or add it as an '
              'OBS browser source. Each link shows only the content named.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled, copyable overlay URL.
class _OverlayLink extends StatelessWidget {
  const _OverlayLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.gurbani.accent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 15),
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy',
                onPressed: () => Clipboard.setData(ClipboardData(text: url)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
