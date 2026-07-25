import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/overlay/overlay_server.dart';

// flutter_test blocks real sockets, so this covers the logic (the served page
// content and the line payload). The live HTTP/WebSocket delivery is verified in
// a browser against the running app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the served page bundles the font and reconnects for updates', () {
    expect(overlayPageHtml, contains('GurbaniAkhar')); // @font-face
    expect(overlayPageHtml, contains('/font.ttf'));
    expect(overlayPageHtml, contains('/ws')); // opens the update socket
    expect(overlayPageHtml, contains('ੴ')); // placeholder before any line
    // Reads the ?show= param so each output can render a different subset.
    expect(overlayPageHtml, contains("get('show')"));
    // Next-line preview: its own element, rendered dimmed (opacity < 1).
    expect(overlayPageHtml, contains('id="nl"'));
    expect(overlayPageHtml, contains('opacity:.5'));
  });

  test(
    'showLine records the line as the JSON a page receives on connect',
    () async {
      final server = OverlayServer();
      await server.start(
        port: 0,
      ); // ephemeral; binds locally, no outbound calls
      addTearDown(server.stop);

      expect(jsonDecode(server.lastLine), <String, dynamic>{}); // nothing yet

      server.showLine(
        gurmukhi: 'ਸਾਜਨ ਦੇਸਿ ਵਿਦੇਸੀਅੜੇ',
        background: '#0B1E3B',
        english: 'O Friend',
        punjabi: 'ਹੇ ਸੱਜਣ',
        roman: 'saajan dhes',
      );

      final line = jsonDecode(server.lastLine) as Map<String, dynamic>;
      expect(line['g'], 'ਸਾਜਨ ਦੇਸਿ ਵਿਦੇਸੀਅੜੇ');
      expect(line['en'], 'O Friend');
      expect(line['pa'], 'ਹੇ ਸੱਜਣ');
      expect(line['roman'], 'saajan dhes');
      expect(line['bg'], '#0B1E3B');
      expect(line['nl'], isNull); // Next Line off unless a preview is passed
    },
  );

  test('showLine carries the next-line preview when Next Line is on', () async {
    final server = OverlayServer();
    await server.start(port: 0);
    addTearDown(server.stop);

    server.showLine(
      gurmukhi: 'ਪਹਿਲੀ ਤੁਕ',
      background: '#0B1E3B',
      nextLine: 'ਅਗਲੀ ਤੁਕ',
    );

    final line = jsonDecode(server.lastLine) as Map<String, dynamic>;
    expect(line['nl'], 'ਅਗਲੀ ਤੁਕ');
  });
}
