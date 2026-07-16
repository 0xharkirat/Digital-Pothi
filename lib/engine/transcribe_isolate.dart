import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'wav.dart';

/// One transcribed window: its display time span and recognized text.
typedef AsrWindow = ({int startMs, int endMs, String text});

/// Decode + transcribe a whole WAV file off the UI isolate so the main thread
/// stays smooth (decode read and the blocking native CTC both run here).
///
/// Overlapping windows: each covers [windowSeconds] of audio but advances by
/// [hopSeconds], so a verse decision lands roughly once per line instead of
/// once per two lines (which caused every-other-line skipping). Each entry's
/// display span is the hop, so entries tile playback time without gaps.
///
/// Returns an empty list if the WAV can't be decoded (unsupported format).
Future<List<AsrWindow>> transcribeWindowsInBackground({
  required String modelPath,
  required String tokensPath,
  required String wavPath,
  double windowSeconds = 6,
  double hopSeconds = 3,
  void Function(double progress)? onProgress,
}) async {
  final rp = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  final completer = Completer<List<AsrWindow>>();

  void finish(List<AsrWindow> result) {
    if (!completer.isCompleted) completer.complete(result);
    rp.close();
    errorPort.close();
    exitPort.close();
  }

  rp.listen((msg) {
    if (msg is double) {
      onProgress?.call(msg);
    } else if (msg is List) {
      finish(msg.cast<AsrWindow>());
    }
  });
  // Any isolate crash or premature exit resolves to empty rather than hanging.
  errorPort.listen((_) => finish(const []));
  exitPort.listen((_) => finish(const []));

  await Isolate.spawn(
    _entry,
    _Args(
      rp.sendPort,
      modelPath,
      tokensPath,
      wavPath,
      windowSeconds,
      hopSeconds,
    ),
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );
  return completer.future;
}

class _Args {
  const _Args(
    this.send,
    this.model,
    this.tokens,
    this.wavPath,
    this.win,
    this.hop,
  );
  final SendPort send;
  final String model;
  final String tokens;
  final String wavPath;
  final double win;
  final double hop;
}

void _entry(_Args a) {
  try {
    _run(a);
  } catch (_) {
    a.send.send(<AsrWindow>[]); // never leave the caller awaiting forever
  }
}

void _run(_Args a) {
  final pcm = decodeWav(a.wavPath);
  if (pcm.sampleRate == 0) {
    a.send.send(<AsrWindow>[]);
    return;
  }
  final samples = pcm.samples;
  final sr = pcm.sampleRate;

  sherpa.initBindings();
  final rec = sherpa.OfflineRecognizer(
    sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(model: a.model),
        tokens: a.tokens,
        numThreads: 2,
        modelType: 'nemo_ctc',
      ),
    ),
  );

  final win = (sr * a.win).round();
  final hop = (sr * a.hop).round();
  final out = <AsrWindow>[];
  for (var start = 0; start < samples.length; start += hop) {
    final end = (start + win).clamp(0, samples.length);
    final stream = rec.createStream();
    stream.acceptWaveform(
      samples: Float32List.sublistView(samples, start, end),
      sampleRate: sr,
    );
    rec.decode(stream);
    final dispEnd = (start + hop).clamp(0, samples.length);
    out.add((
      startMs: (start * 1000) ~/ sr,
      endMs: (dispEnd * 1000) ~/ sr,
      text: rec.getResult(stream).text.trim(),
    ));
    stream.free();
    a.send.send(end / samples.length);
  }
  rec.free();
  a.send.send(out);
}
