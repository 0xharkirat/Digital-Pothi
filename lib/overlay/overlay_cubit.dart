import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'output_window.dart';
import 'overlay_server.dart';

class OverlayStatus extends Equatable {
  const OverlayStatus({
    this.running = false,
    this.url = '',
    this.outputOpen = false,
  });

  final bool running;
  final String url;

  /// True while the native fullscreen output window is open.
  final bool outputOpen;

  OverlayStatus copyWith({bool? running, String? url, bool? outputOpen}) =>
      OverlayStatus(
        running: running ?? this.running,
        url: url ?? this.url,
        outputOpen: outputOpen ?? this.outputOpen,
      );

  @override
  List<Object> get props => [running, url, outputOpen];
}

/// Owns the [OverlayServer] lifecycle and its address, and forwards the current
/// line to it. Toggling on binds the server and resolves a LAN URL to show the
/// operator; toggling off tears it down.
class OverlayCubit extends Cubit<OverlayStatus> {
  OverlayCubit(this._server) : super(const OverlayStatus());

  final OverlayServer _server;
  final _output = OutputWindow();

  Future<void> toggle() async {
    if (state.running) {
      _output.close();
      await _server.stop();
      emit(const OverlayStatus());
    } else {
      await _server.start();
      final host = await _server.hostAddress();
      emit(OverlayStatus(running: true, url: 'http://$host:${_server.port}'));
    }
  }

  /// Open (or re-point) the native fullscreen output window at [url]. The URL
  /// carries the `?show=` content choice for this output.
  Future<void> openOutput(String url) async {
    final ok = await _output.open(
      url,
      onClosed: () {
        if (!isClosed) emit(state.copyWith(outputOpen: false));
      },
    );
    emit(state.copyWith(outputOpen: ok));
  }

  void closeOutput() {
    _output.close();
    emit(state.copyWith(outputOpen: false));
  }

  void showLine({
    required String gurmukhi,
    required String background,
    String? english,
    String? punjabi,
    String? roman,
    bool larivaar = false,
    bool vishraam = true,
    double fontScale = 1.0,
    double translationScale = 1.0,
    double teekaScale = 1.0,
    double translitScale = 1.0,
    String text = '#FBF3E3',
    String accent = '#F0B429',
  }) {
    if (!state.running) return;
    _server.showLine(
      gurmukhi: gurmukhi,
      background: background,
      english: english,
      punjabi: punjabi,
      roman: roman,
      larivaar: larivaar,
      vishraam: vishraam,
      fontScale: fontScale,
      translationScale: translationScale,
      teekaScale: teekaScale,
      translitScale: translitScale,
      text: text,
      accent: accent,
    );
  }

  @override
  Future<void> close() async {
    _output.close();
    await _server.stop();
    return super.close();
  }
}
