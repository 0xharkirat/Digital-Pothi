import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/engine/wav.dart';

/// Build a minimal 16-bit PCM WAV with the given interleaved int16 samples.
Uint8List _wav(
  List<int> interleaved, {
  int channels = 2,
  int sampleRate = 22050,
}) {
  final data = ByteData(interleaved.length * 2);
  for (var i = 0; i < interleaved.length; i++) {
    data.setInt16(i * 2, interleaved[i], Endian.little);
  }
  final dataLen = data.lengthInBytes;
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  str('RIFF');
  u32(36 + dataLen);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * channels * 2); // byte rate
  u16(channels * 2); // block align
  u16(16); // bits
  str('data');
  u32(dataLen);
  b.add(data.buffer.asUint8List());
  return b.toBytes();
}

void main() {
  group('decodeWav', () {
    test('downmixes stereo to mono at the native rate', () {
      final file = File(
        '${Directory.systemTemp.path}/t_${identityHashCode([])}.wav',
      )..writeAsBytesSync(_wav([100, 300, 200, 200, 300, 100])); // L,R pairs
      addTearDown(() => file.deleteSync());

      final pcm = decodeWav(file.path);
      expect(pcm.sampleRate, 22050);
      expect(pcm.samples.length, 3); // 3 frames from 6 interleaved values
      // each frame averages L and R = 200 -> 200/32768
      for (final s in pcm.samples) {
        expect(s, closeTo(200 / 32768.0, 1e-6));
      }
    });

    test('returns empty on a non-WAV file', () {
      final file = File(
        '${Directory.systemTemp.path}/n_${identityHashCode(Object())}.bin',
      )..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));
      addTearDown(() => file.deleteSync());
      expect(decodeWav(file.path).sampleRate, 0);
    });
  });
}
