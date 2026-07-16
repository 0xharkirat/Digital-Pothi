import 'package:desktop_webview_window/desktop_webview_window.dart';

/// A dedicated native webview window that renders the overlay page - the
/// projector output, without a second Flutter engine. Borderless and maximised;
/// drag it onto the projector / extended display and it fills the screen.
///
/// The window just points at the local overlay URL, so it shows exactly what
/// every other overlay client shows, and the `?show=` param on the URL decides
/// which content this particular output renders.
class OutputWindow {
  Webview? _webview;

  bool get isOpen => _webview != null;

  /// Open (or re-point) the output window at [url]. Returns false if the host
  /// has no system webview available. [onClosed] fires if the user closes the
  /// window from the OS.
  Future<bool> open(String url, {void Function()? onClosed}) async {
    final existing = _webview;
    if (existing != null) {
      existing.launch(url);
      await _maximise(existing);
      return true;
    }
    if (!await WebviewWindow.isWebviewAvailable()) return false;
    final webview = await WebviewWindow.create(
      configuration: const CreateConfiguration(
        title: 'Gurbani Live - Output',
        // Keep a title bar so the window can be dragged to the projector. A
        // titleBarHeight of 0 leaves no grab region and the window is stuck;
        // for a true full-screen projector, use the window's own full-screen
        // button once it's on the right display.
        windowWidth: 1600,
        windowHeight: 900,
      ),
    );
    _webview = webview;
    webview
      ..launch(url)
      ..onClose.then((_) {
        _webview = null;
        onClosed?.call();
      });
    await _maximise(webview);
    return true;
  }

  /// Best-effort maximise + foreground. Implemented on Windows/Linux; macOS's
  /// build of the plugin has no such method (the window opens at the configured
  /// size - use the green full-screen button), so the MissingPluginException is
  /// swallowed rather than crashing the caller.
  Future<void> _maximise(Webview webview) async {
    try {
      await webview.bringToForeground(maximized: true);
    } catch (_) {}
  }

  void close() {
    _webview?.close();
    _webview = null;
  }
}
