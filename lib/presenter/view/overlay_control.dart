import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../overlay/overlay_cubit.dart';
import '../../theme/app_theme.dart';

/// The content each output renders, chosen with the overlay URL's `?show=`
/// param. Minimal = just the shabad + Punjabi teeka; full = everything.
const _showMinimal = 'gurmukhi,punjabi';
const _showFull = 'gurmukhi,punjabi,english,roman';

bool get _isDesktopHost =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Start/stop the LAN overlay, open the native fullscreen output window, and
/// offer ready-made links - each showing a different subset of the content.
/// Lives in the Settings screen's Projector / Overlay section.
class OverlayControl extends StatelessWidget {
  const OverlayControl({super.key});

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
