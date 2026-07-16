import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme/app_theme.dart';
import '../../tracking/cubit/tracking_cubit.dart';
import '../cubit/presenter_cubit.dart';

/// Bottom-right "Controls" tab: what's showing and the AI auto-follow (mic /
/// audio file). Display + projector settings live in the settings drawer; line
/// and shabad navigation live on the shabad pane.
class ControlsPane extends StatelessWidget {
  const ControlsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final presenter = context.read<PresenterCubit>();
    final tracking = context.read<TrackingCubit>();
    final theme = Theme.of(context);
    final g = context.gurbani;

    return BlocBuilder<PresenterCubit, PresenterState>(
      builder: (context, state) {
        final meta = [
          if (state.author.isNotEmpty) state.author,
          if (state.section.isNotEmpty) state.section,
          if (state.line != null) 'Ang ${state.line!.page}',
        ].join('  ·  ');

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'NOW SHOWING',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta.isEmpty ? 'Nothing selected' : meta,
              style: theme.textTheme.bodyMedium,
            ),
            const Divider(height: 28),
            Text(
              'AI AUTO-FOLLOW',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _FollowButton(following: state.following),
            const SizedBox(height: 8),
            BlocBuilder<TrackingCubit, TrackingState>(
              builder: (context, t) => TextButton.icon(
                onPressed: t.isBusy
                    ? null
                    : () async {
                        presenter.setFollowing(on: true);
                        await tracking.pickFile();
                      },
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Follow an audio file'),
              ),
            ),
            const _FilePlayback(),
            const SizedBox(height: 20),
            Text(
              'Search and tap a line, or let the AI follow the live recitation.',
              style: theme.textTheme.bodySmall?.copyWith(color: g.accent),
            ),
          ],
        );
      },
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.following});
  final bool following;

  @override
  Widget build(BuildContext context) {
    final presenter = context.read<PresenterCubit>();
    final tracking = context.read<TrackingCubit>();
    final accent = context.gurbani.accent;
    return FilledButton.icon(
      onPressed: () {
        final on = !following;
        presenter.setFollowing(on: on);
        // Start/stop the mic tracker to match the toggle.
        if (tracking.state.isListening != on) tracking.toggleMic();
      },
      style: FilledButton.styleFrom(
        backgroundColor: following ? accent : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: Icon(following ? Icons.graphic_eq : Icons.mic),
      label: Text(following ? 'Following live audio' : 'Start AI follow (mic)'),
    );
  }
}

/// Feedback while following an audio file: a transcribing indicator, then
/// play/pause + seek. Without this, picking a file looks like nothing happened.
class _FilePlayback extends StatelessWidget {
  const _FilePlayback();

  @override
  Widget build(BuildContext context) {
    final tracking = context.read<TrackingCubit>();
    final theme = Theme.of(context);
    return BlocBuilder<TrackingCubit, TrackingState>(
      builder: (context, t) {
        if (t.status == TrackingStatus.transcribing) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Transcribing ${(t.progress * 100).round()}%…',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        }
        if (!t.hasAudio) return const SizedBox.shrink();
        final maxMs = t.duration.inMilliseconds == 0
            ? 1
            : t.duration.inMilliseconds;
        return Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(t.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: tracking.togglePlayPause,
                ),
                Expanded(
                  child: Slider(
                    value: t.position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    max: maxMs.toDouble(),
                    onChanged: (v) =>
                        tracking.seek(Duration(milliseconds: v.round())),
                  ),
                ),
              ],
            ),
            Text(
              '${_fmt(t.position)} / ${_fmt(t.duration)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
