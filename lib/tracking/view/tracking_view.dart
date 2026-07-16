import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme/app_theme.dart';
import '../cubit/tracking_cubit.dart';

/// Renders tracking state and forwards user intent to the cubit. No logic here.
class TrackingView extends StatelessWidget {
  const TrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<TrackingCubit, TrackingState>(
      builder: (context, state) {
        final cubit = context.read<TrackingCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gurbani Live'),
            centerTitle: true,
            actions: [
              IconButton(
                key: const Key('open_file'),
                icon: const Icon(Icons.folder_open),
                tooltip: 'Open audio file',
                onPressed: state.isBusy ? null : cubit.pickFile,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_label(state), style: theme.textTheme.labelLarge),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Center(child: _VerseBody(state: state)),
              ),
              if (state.hasAudio) _Transport(state: state, cubit: cubit),
              if (state.lastHeard.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'heard: ${state.lastHeard}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.large(
            key: const Key('mic_toggle'),
            tooltip: state.isListening ? 'Stop listening' : 'Start listening',
            onPressed: cubit.toggleMic,
            child: Icon(state.isListening ? Icons.stop : Icons.mic),
          ),
        );
      },
    );
  }
}

class _VerseBody extends StatelessWidget {
  const _VerseBody({required this.state});
  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.isBusy) return const CircularProgressIndicator();
    final verse = state.verse;
    if (verse == null) {
      return Text(
        '…',
        style: theme.textTheme.headlineMedium,
        semanticsLabel: 'Searching for verse',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            verse.gurmukhi,
            textAlign: TextAlign.center,
            style: context.gurbani.gurmukhi.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 12),
          Text('Ang ${verse.page}', style: theme.textTheme.labelMedium),
          if (state.isListening || state.hasAudio) ...[
            const SizedBox(height: 8),
            _SyncBadge(synced: state.synced),
          ],
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.synced});
  final bool synced;

  @override
  Widget build(BuildContext context) {
    final color = synced ? Colors.green : Colors.amber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(synced ? Icons.check_circle : Icons.sync, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          synced ? 'on line' : 'catching up…',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.state, required this.cubit});
  final TrackingState state;
  final TrackingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final maxMs = state.duration.inMilliseconds == 0
        ? 1
        : state.duration.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            key: const Key('play_pause'),
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: cubit.togglePlayPause,
          ),
          Expanded(
            child: Slider(
              value: state.position.inMilliseconds.clamp(0, maxMs).toDouble(),
              max: maxMs.toDouble(),
              label: 'Seek',
              semanticFormatterCallback: (v) =>
                  _fmt(Duration(milliseconds: v.round())),
              onChanged: (v) => cubit.seek(Duration(milliseconds: v.round())),
            ),
          ),
          Text(
            '${_fmt(state.position)} / ${_fmt(state.duration)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

String _label(TrackingState s) => switch (s.status) {
  TrackingStatus.idle => 'Tap the mic, or open an audio file',
  TrackingStatus.loadingModel => 'Loading model…',
  TrackingStatus.listening => 'Listening…',
  TrackingStatus.transcribing => 'Transcribing ${(s.progress * 100).round()}%…',
  TrackingStatus.playing => 'Playing',
  TrackingStatus.paused => 'Paused',
  TrackingStatus.finished => 'Finished',
  TrackingStatus.micDenied => 'Microphone permission denied',
  TrackingStatus.fileError => 'Could not read that WAV (16-bit PCM only)',
};

String _fmt(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
