import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';

import '../../asr_service.dart';
import '../../data/gurbani_database.dart';
import '../../engine/corpus.dart';
import '../../engine/line_checker.dart';
import '../../engine/normalizer.dart';
import '../../engine/phrase_filter.dart';
import '../../engine/transcribe_isolate.dart';
import '../../engine/similarity.dart';
import '../../engine/smooth.dart';

part 'tracking_state.dart';

/// Drives tracking: mic or a picked WAV → ASR → *discover* where in the corpus
/// we are → follow the line. Business logic lives here; the view renders state.
///
/// Discover, not "load a bani": every chunk goes through [_advance], which
/// locates against the whole 141k-line corpus on a cold start, anchors on a
/// window of lines around the hit, and then follows inside that window with the
/// [LineChecker]. The follower never scans more than the window.
class TrackingCubit extends Cubit<TrackingState> {
  TrackingCubit({
    required GurbaniDatabase database,
    GurbaniAsr? asr,
    AudioPlayer? player,
    Future<String?> Function()? pickPath,
    this.leadMs = 2500,
    this.anchorThreshold = 0.45,
    this.escapeThreshold = 0.45,
    this.relocateAfter = 3,
    this.edgeMargin = 25,
    this.tieMargin = 0.08,
    this.locateWindow = 8,
  }) : _db = database,
       _asr = asr ?? GurbaniAsr(),
       _player = player ?? AudioPlayer(),
       _pickPath = pickPath ?? _defaultPickPath,
       super(const TrackingState());

  final GurbaniDatabase _db;
  final GurbaniAsr _asr;
  final AudioPlayer _player;
  final Future<String?> Function() _pickPath;

  /// A transcription window covers audio *ahead* of its start time, so the raw
  /// timeline runs early. Show each verse this many ms later. Calibration knob.
  final int leadMs;

  /// Minimum score, over the joined [locateWindow], before we anchor on a hit.
  /// A real shabad's asthaai accumulates past ~0.5 across a dozen chunks; the
  /// garble an instrumental passage transcribes to tops out near 0.4, so the bar
  /// sits between them. (File mode has no VAD, so it transcribes the music too.)
  final double anchorThreshold;

  /// Bar for *leaving* the anchor window entirely, which is a much bigger claim
  /// than moving inside it: across 141k lines, ASR noise always matches
  /// something somewhere, and at [anchorThreshold] a single garbled chunk is
  /// enough to teleport the tracker out of the bani. Judged against the joined
  /// [locateWindow], not one chunk, so accumulated signal has to clear it.
  /// Calibration knob.
  final double escapeThreshold;

  /// How many recent chunks the *locator* sees at once (cold start and escape).
  /// A single kirtan chunk is a fragment - the singer holds one line across
  /// several 6s windows - so no one chunk carries enough signal to find the
  /// shabad or to justify leaving the one we hold. Joined, the repeated asthaai
  /// rises well above the noise floor (measured on real kirtan: the true line
  /// went from ~0.35 per fragment to ~0.55 across a dozen, while noise fragments
  /// scatter and never accumulate). The follower is unaffected - within a shabad
  /// the line-to-line signal is there per chunk, and accumulation would blur it.
  final int locateWindow;

  /// Consecutive out-of-sync chunks before we re-locate (a jump, or a pramaan
  /// quoted from another shabad).
  final int relocateAfter;

  /// Re-anchor when the follower gets this close to the window's edge.
  final int edgeMargin;

  /// Hits within this much of the best one count as tied, and are disambiguated
  /// rather than guessed between. Calibration knob: too small and a coin flip
  /// slips through, too large and every cold start waits an extra chunk.
  final double tieMargin;

  static Future<String?> _defaultPickPath() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );
    return picked?.files.single.path;
  }

  List<Verse> _anchor = const [];
  LineChecker? _checker;
  int _lost = 0;

  /// Recent cleaned chunks, joined for locating. See [locateWindow].
  final _recent = <String>[];

  /// Tied cold-start candidates, held for the next chunk to break.
  List<LocateHit> _pending = const [];
  StreamSubscription<String>? _textSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;
  List<_Entry> _timeline = const [];

  void _resetTracking() {
    _anchor = const [];
    _checker = null;
    _lost = 0;
    _pending = const [];
    _recent.clear();
  }

  /// Push a chunk into the rolling locate buffer and return it joined.
  String _remember(String clean) {
    _recent.add(clean);
    if (_recent.length > locateWindow) _recent.removeAt(0);
    return _recent.join(' ');
  }

  // ---- discover + follow ----------------------------------------------------

  /// Load the corpus window around a known line and put the follower on it.
  ///
  /// Synchronous - package:sqlite3 queries don't await, so two chunks can't
  /// interleave a search even though this runs inside a stream listener.
  bool _anchorOn(int orderId, String lineId) {
    final window = _db.windowAround(orderId);
    final at = window.indexWhere((v) => v.id == lineId);
    if (at < 0) return false;
    _anchor = window;
    _checker = LineChecker(window)..seek(at);
    _lost = 0;
    return true;
  }

  /// Cold start: find where in the corpus we are, but don't commit on a tie.
  ///
  /// The corpus repeats whole lines verbatim across sources - Japji's
  /// "ਆਦਿ ਸਚੁ ਜੁਗਾਦਿ ਸਚੁ" is also Sukhmani's, on ang 285, character for character -
  /// so one chunk genuinely cannot say which is being recited. Committing anyway
  /// is a coin flip that strands the follower in the wrong bani. Hold the tied
  /// candidates instead and let the next chunk decide: by then the reciter has
  /// moved on to a line where the two passages differ (Japji "ਹੈ ਭੀ ਸਚੁ" against
  /// Sukhmani's "ਹੈ ਭਿ ਸਚੁ" - one vowel, and it settles it).
  bool _cold(String clean) {
    if (_pending.isNotEmpty) {
      final votes = [for (final hit in _pending) _followOn(hit, clean)]
        ..sort((a, b) => b.score.compareTo(a.score));
      _pending = const [];
      final won = votes.first;
      if (won.verse != null && won.score >= anchorThreshold) {
        return _anchorOn(won.verse!.seq, won.verse!.id);
      }
      // Tie unresolved (a slow reciter still on the same line). Search afresh.
    }

    final hits = _db.locate(clean);
    if (hits.isEmpty || hits.first.score < anchorThreshold) return false;

    final tied = hits
        .where((h) => hits.first.score - h.score < tieMargin)
        .toList();
    if (tied.length > 1) {
      _pending = tied; // wait one chunk rather than guess
      return false;
    }
    return _anchorOn(hits.first.orderId, hits.first.lineId);
  }

  /// Best match for [clean] among the lines *after* [hit] - the evidence that
  /// tells two verbatim-identical lines apart, and the line to start following.
  ({Verse? verse, double score}) _followOn(LocateHit hit, String clean) {
    final query = normalize(clean);
    Verse? best;
    var score = 0.0;
    for (final verse in _db.windowAround(hit.orderId, radius: 4)) {
      if (verse.seq <= hit.orderId) continue;
      final s = lineSimilarity(query, verse.normalized);
      if (s > score) {
        score = s;
        best = verse;
      }
    }
    return (verse: best, score: score);
  }

  /// Lost for a while: the reciter jumped - back to the asthaai, out into a
  /// pramaan from another shabad, or on into the next bani.
  ///
  /// [windowClean] is the single chunk - enough to catch a return *inside* the
  /// current shabad, where the window is small and one distinctive line settles
  /// it, and kept single so the snap back to the asthaai stays immediate.
  /// [locateText] is the joined [locateWindow], used only for the far bigger
  /// claim of leaving the shabad entirely (see [escapeThreshold]).
  bool _relocate(String windowClean, String locateText) {
    final query = normalize(windowClean);

    // The anchor window first. It is already in memory, and being mid-recitation
    // is a strong prior: a jump is nearly always *within* what is being sung -
    // back to the asthaai, or past the follower's few-line horizon. Asking the
    // whole corpus first lets one noisy chunk that happens to match a quotation
    // in some other source drag the tracker out of the bani entirely.
    Verse? near;
    var best = 0.0;
    for (final verse in _anchor) {
      final s = lineSimilarity(query, verse.normalized);
      if (s > best) {
        best = s;
        near = verse;
      }
    }
    if (near != null && best >= anchorThreshold) {
      return _anchorOn(near.seq, near.id);
    }

    // Nothing in the window matches: they really have left it. Judge the exit on
    // the accumulated buffer, where a new shabad's asthaai has built up signal,
    // not on the one noisy chunk that happened to fall out of the window.
    final hits = _db.locate(locateText);
    if (hits.isEmpty || hits.first.score < escapeThreshold) return false;

    // Among equally good hits, take the one nearest to where we already are: a
    // reciter returns to their own refrain far more often than they teleport to
    // an identical tuk in another raag.
    final here = _anchor[_checker!.current].seq;
    final hit = hits
        .where((h) => hits.first.score - h.score < tieMargin)
        .reduce(
          (a, b) =>
              (a.orderId - here).abs() <= (b.orderId - here).abs() ? a : b,
        );
    return _anchorOn(hit.orderId, hit.lineId);
  }

  /// Slide the anchor so the follower always has lines ahead of and behind it.
  /// Re-centres on the line we already hold, rather than searching again: a
  /// global search here could teleport us onto an identical tuk elsewhere.
  void _slide(Verse here) {
    final window = _db.windowAround(here.seq);
    // At a corpus edge the window can't move (Japji starts on ang 1), so the
    // follower sits inside edgeMargin for its whole first bani. Bail out rather
    // than re-query and rebuild on every chunk to produce the same window.
    if (window.first.seq == _anchor.first.seq &&
        window.last.seq == _anchor.last.seq) {
      return;
    }
    final at = window.indexWhere((v) => v.id == here.id);
    if (at < 0) return;
    _anchor = window;
    _checker = LineChecker(window)..seek(at);
  }

  /// One transcript chunk → the verse to show. Shared by mic and file.
  ({Verse? verse, bool synced}) _advance(String clean) {
    final locateText = _remember(clean);
    if (_checker == null && !_cold(locateText)) {
      return (verse: null, synced: false); // still searching the corpus
    }

    var check = _checker!.check(clean);
    // Lost means *nothing* nearby matched - not merely "hasn't confirmed the
    // move yet", which is what an ordinary line change looks like for a chunk or
    // two. Conflating the two makes every normal advance count toward a
    // re-locate, and the tracker relocates its way out of the bani.
    if (check.score < _checker!.floor) {
      _lost++;
      if (_lost >= relocateAfter && _relocate(clean, locateText)) {
        check = _checker!.check(clean);
      }
    } else {
      _lost = 0;
    }

    final here = _anchor[check.index];
    if (check.index < edgeMargin ||
        check.index >= _anchor.length - edgeMargin) {
      _slide(here);
    }
    return (verse: here, synced: check.synced);
  }

  // ---- mic mode -------------------------------------------------------------

  Future<void> toggleMic() async {
    if (state.isListening) {
      await _asr.stop();
      emit(const TrackingState());
      return;
    }
    await _stopPlayback();
    emit(const TrackingState(status: TrackingStatus.loadingModel));
    _resetTracking();
    _textSub ??= _asr.onText.listen(_onText);

    final ok = await _asr.start();
    if (isClosed) return;
    emit(
      TrackingState(
        status: ok ? TrackingStatus.listening : TrackingStatus.micDenied,
      ),
    );
  }

  void _onText(String text) {
    final clean = stripNonVerse(text);
    if (clean.isEmpty) {
      emit(state.copyWith(lastHeard: text));
      return;
    }
    final result = _advance(clean);
    emit(
      state.copyWith(
        lastHeard: text,
        verse: result.verse ?? state.verse,
        synced: result.synced,
      ),
    );
  }

  // ---- file mode (karaoke) --------------------------------------------------

  Future<void> pickFile() async {
    final path = await _pickPath();
    if (path != null) await trackFile(path);
  }

  Future<void> trackFile(String path) async {
    if (state.isListening) await _asr.stop();
    await _stopPlayback();
    _resetTracking();
    if (isClosed) return;
    emit(const TrackingState(status: TrackingStatus.transcribing));

    final windows = await _asr.recognizeWindows(
      path,
      onProgress: (p) {
        if (!isClosed) emit(state.copyWith(progress: p));
      },
    );
    if (isClosed) return;
    if (windows.isEmpty) {
      emit(const TrackingState(status: TrackingStatus.fileError));
      return;
    }
    _timeline = _buildTimeline(windows);

    emit(const TrackingState(status: TrackingStatus.playing));
    _posSub = _player.onPositionChanged.listen((pos) {
      final shown = _verseAt(pos.inMilliseconds - leadMs);
      final playingNow = _verseAt(pos.inMilliseconds);
      emit(
        state.copyWith(
          position: pos,
          verse: shown ?? state.verse,
          // On line when the shown (lead-delayed) verse is the one playing now;
          // "catching up" during the brief lead window after a line changes.
          synced:
              shown == null || playingNow == null || shown.id == playingNow.id,
        ),
      );
    });
    _durSub = _player.onDurationChanged.listen(
      (d) => emit(state.copyWith(duration: d)),
    );
    _stateSub = _player.onPlayerStateChanged.listen(_onPlayerState);
    await _player.play(DeviceFileSource(path));
  }

  void _onPlayerState(PlayerState s) {
    switch (s) {
      case PlayerState.playing:
        emit(state.copyWith(status: TrackingStatus.playing));
      case PlayerState.paused:
        emit(state.copyWith(status: TrackingStatus.paused));
      case PlayerState.completed:
        emit(state.copyWith(status: TrackingStatus.finished));
      case PlayerState.stopped:
      case PlayerState.disposed:
        break;
    }
  }

  Future<void> togglePlayPause() async {
    if (!state.hasAudio) return;
    if (state.isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration to) async {
    if (!state.hasAudio) return;
    await _player.seek(to);
    if (isClosed) return;
    emit(
      state.copyWith(
        position: to,
        verse: _verseAt(to.inMilliseconds - leadMs) ?? state.verse,
      ),
    );
  }

  // ---- internals ------------------------------------------------------------

  List<_Entry> _buildTimeline(List<AsrWindow> windows) {
    final raw = [for (final w in windows) _verseForWindow(w.text)];
    final smoothed = smoothForward(raw);
    return [
      for (var i = 0; i < windows.length; i++)
        _Entry(windows[i].startMs, windows[i].endMs, smoothed[i]),
    ];
  }

  /// Strip ritual/announcement phrases, then discover+follow the residue. A
  /// pure-invocation window returns null so it can't drag the tracker away.
  Verse? _verseForWindow(String text) {
    final clean = stripNonVerse(text);
    return clean.isEmpty ? null : _advance(clean).verse;
  }

  Verse? _verseAt(int ms) {
    for (final e in _timeline) {
      if (ms >= e.startMs && ms < e.endMs) return e.verse;
    }
    return _timeline.isNotEmpty && ms >= _timeline.last.endMs
        ? _timeline.last.verse
        : null;
  }

  Future<void> _stopPlayback() async {
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _stateSub?.cancel();
    _posSub = _durSub = _stateSub = null;
    await _player.stop();
  }

  @override
  Future<void> close() async {
    await _textSub?.cancel();
    await _stopPlayback();
    await _player.dispose();
    await _asr.dispose();
    return super.close();
  }
}

/// A stretch of playback time mapped to the verse to show during it.
class _Entry {
  const _Entry(this.startMs, this.endMs, this.verse);
  final int startMs;
  final int endMs;
  final Verse? verse;
}
