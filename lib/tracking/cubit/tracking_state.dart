part of 'tracking_cubit.dart';

enum TrackingStatus {
  idle,
  loadingModel,
  listening,
  transcribing,
  playing,
  paused,
  finished,
  micDenied,
  fileError,
}

class TrackingState extends Equatable {
  const TrackingState({
    this.status = TrackingStatus.idle,
    this.verse,
    this.lastHeard = '',
    this.progress = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.synced = true,
  });

  final TrackingStatus status;

  /// Verse to display right now, or null while searching.
  final Verse? verse;

  /// Live-checker signal: true when the shown verse is confirmed current, false
  /// while the reciter appears to have moved and we're confirming the next line.
  final bool synced;

  /// Last raw transcript heard (mic mode debug line).
  final String lastHeard;

  /// File transcription progress, 0..1.
  final double progress;

  final Duration position;
  final Duration duration;

  bool get hasAudio =>
      status == TrackingStatus.playing ||
      status == TrackingStatus.paused ||
      status == TrackingStatus.finished;
  bool get isPlaying => status == TrackingStatus.playing;
  bool get isListening => status == TrackingStatus.listening;
  bool get isBusy =>
      status == TrackingStatus.loadingModel ||
      status == TrackingStatus.transcribing;

  TrackingState copyWith({
    TrackingStatus? status,
    Verse? verse,
    String? lastHeard,
    double? progress,
    Duration? position,
    Duration? duration,
    bool? synced,
  }) {
    return TrackingState(
      status: status ?? this.status,
      verse: verse ?? this.verse,
      lastHeard: lastHeard ?? this.lastHeard,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      synced: synced ?? this.synced,
    );
  }

  @override
  List<Object?> get props => [
    status,
    verse,
    lastHeard,
    progress,
    position,
    duration,
    synced,
  ];
}
