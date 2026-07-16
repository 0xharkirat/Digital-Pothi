import 'dart:io';
import 'dart:typed_data';

/// Decoded PCM audio: mono float samples in [-1, 1] plus the native rate.
typedef Pcm = ({Float32List samples, int sampleRate});

/// Minimal WAV decoder. Handles 16-bit PCM at any channel count / sample rate
/// by downmixing to mono; the ASR recognizer resamples to 16 kHz itself.
///
/// We parse WAV ourselves instead of sherpa's readWave, which is mono-only and
/// silently mishandles the stereo/22 kHz files people actually pick.
/// ponytail: 16-bit PCM WAV only - the common case. Other bit depths / codecs
/// (mp3, 24-bit) need a real decoder; add one when a file actually needs it.
Pcm decodeWav(String path) {
  final bytes = File(path).readAsBytesSync();
  final bd = ByteData.sublistView(bytes);

  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    return (samples: Float32List(0), sampleRate: 0);
  }

  var channels = 1;
  var sampleRate = 0;
  var bits = 16;
  var dataOffset = -1;
  var dataLen = 0;

  var p = 12;
  while (p + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(p, p + 4));
    final size = bd.getUint32(p + 4, Endian.little);
    final body = p + 8;
    if (id == 'fmt ' && body + 16 <= bytes.length) {
      channels = bd.getUint16(body + 2, Endian.little);
      sampleRate = bd.getUint32(body + 4, Endian.little);
      bits = bd.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      dataOffset = body;
      dataLen = size;
    }
    p = body + size + (size.isOdd ? 1 : 0); // chunks are word-aligned
  }

  if (dataOffset < 0 || sampleRate == 0 || bits != 16 || channels < 1) {
    return (samples: Float32List(0), sampleRate: 0);
  }

  final end = (dataOffset + dataLen).clamp(0, bytes.length);
  final frames = (end - dataOffset) ~/ (2 * channels);
  final out = Float32List(frames);
  var o = dataOffset;
  for (var i = 0; i < frames; i++) {
    var sum = 0;
    for (var c = 0; c < channels; c++) {
      sum += bd.getInt16(o, Endian.little);
      o += 2;
    }
    out[i] = (sum / channels) / 32768.0;
  }
  return (samples: out, sampleRate: sampleRate);
}
