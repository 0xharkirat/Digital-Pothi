import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'engine/transcribe_isolate.dart';

/// mic -> Silero VAD -> IndicConformer-CTC (ONNX) -> Gurmukhi, plus file
/// transcription off the UI isolate. Native on macOS/Windows/Android/iOS via
/// sherpa_onnx. No Python, no Rust.
class GurbaniAsr {
  GurbaniAsr({this.sampleRate = 16000});

  final int sampleRate;

  sherpa.OfflineRecognizer? _recognizer;
  sherpa.VoiceActivityDetector? _vad;
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  bool _ready = false;
  String? _modelPath;
  String? _tokensPath;
  String? _sileroPath;

  /// Emits each finalized speech segment's transcript (mic mode).
  final _controller = StreamController<String>.broadcast();
  Stream<String> get onText => _controller.stream;

  /// Copy the bundled model assets to disk once and cache their paths.
  Future<void> _ensurePaths() async {
    _modelPath ??= await _asset('assets/models/indicconformer-pa-ctc.onnx');
    _tokensPath ??= await _asset('assets/models/tokens.txt');
    _sileroPath ??= await _asset('assets/models/silero_vad.onnx');
  }

  Future<void> init() async {
    if (_ready) return;
    sherpa.initBindings();
    await _ensurePaths();

    _recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(model: _modelPath!),
          tokens: _tokensPath!,
          numThreads: 2,
          modelType: 'nemo_ctc',
          debug: false,
        ),
      ),
    );

    _vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: _sileroPath!,
          // ponytail: Silero is speech-tuned; these three are the knobs to
          // retune for sung kirtan (Handy uses threshold 0.3 + long hangover).
          threshold: 0.5,
          minSilenceDuration: 0.25,
          minSpeechDuration: 0.25,
          maxSpeechDuration: 12.0,
        ),
        numThreads: 1,
        sampleRate: sampleRate,
      ),
      bufferSizeInSeconds: 30,
    );

    _ready = true;
  }

  Future<bool> start() async {
    await init();
    if (!await _recorder.hasPermission()) return false;

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );

    _micSub = stream.listen(_onPcm);
    return true;
  }

  void _onPcm(Uint8List bytes) {
    final vad = _vad;
    final rec = _recognizer;
    if (vad == null || rec == null) return;

    vad.acceptWaveform(_pcm16ToFloat32(bytes));

    while (!vad.isEmpty()) {
      final segment = vad.front();
      final stream = rec.createStream();
      stream.acceptWaveform(samples: segment.samples, sampleRate: sampleRate);
      rec.decode(stream);
      final text = rec.getResult(stream).text.trim();
      stream.free();
      vad.pop();
      if (text.isNotEmpty) _controller.add(text);
    }
  }

  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    await _recorder.stop();
    _vad?.flush();
    _vad?.clear();
  }

  /// Decode + transcribe a WAV file into a verse-tracking timeline, running
  /// everything (file read + blocking native CTC) on a background isolate so
  /// the UI stays smooth. Overlapping windows land a decision ~once per line.
  /// Returns an empty list if the file can't be decoded.
  Future<List<AsrWindow>> recognizeWindows(
    String wavPath, {
    double windowSeconds = 6,
    double hopSeconds = 3,
    void Function(double progress)? onProgress,
  }) async {
    await _ensurePaths();
    return transcribeWindowsInBackground(
      modelPath: _modelPath!,
      tokensPath: _tokensPath!,
      wavPath: wavPath,
      windowSeconds: windowSeconds,
      hopSeconds: hopSeconds,
      onProgress: onProgress,
    );
  }

  Future<void> dispose() async {
    await stop();
    _recognizer?.free();
    _vad?.free();
    await _controller.close();
  }

  /// sherpa needs real file paths, so copy bundled assets to a temp dir once.
  Future<String> _asset(String key) async {
    final dir = await getApplicationSupportDirectory();
    final out = File('${dir.path}/${key.split('/').last}');
    if (!await out.exists()) {
      final data = await rootBundle.load(key);
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return out.path;
  }

  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final n = bytes.lengthInBytes ~/ 2;
    final view = ByteData.sublistView(bytes);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}
