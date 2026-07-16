import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// A tiny local HTTP + WebSocket server that serves a full-screen "bani overlay"
/// page - for a projector browser (open the URL, press F11), OBS as a browser
/// source, or any device on the LAN. It is fed the current line and pushes it to
/// every connected page: the same state-delta model STTM's projector uses, just
/// a few strings over a socket instead of pixels.
///
/// Deliberately dependency-free (dart:io). Binds to all interfaces so other
/// machines on the network can reach it.
class OverlayServer {
  HttpServer? _server;
  final _clients = <WebSocket>[];

  /// Last line as JSON, replayed to a page the moment it connects (so a newly
  /// opened projector catches up instead of showing a blank screen).
  String _last = '{}';
  Uint8List? _font;

  bool get running => _server != null;
  int? get port => _server?.port;

  /// The current line as JSON (what a page gets on connect). Exposed for tests -
  /// flutter_test blocks real sockets, so the delivery path is browser-verified.
  String get lastLine => _last;

  /// A LAN address other devices can use (falls back to localhost).
  Future<String> hostAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (!a.isLoopback) return a.address;
      }
    }
    return 'localhost';
  }

  /// Start on [port] (a Sikh-history year, like STTM's overlay ports).
  Future<void> start({int port = 1699}) async {
    if (_server != null) return;
    // The page still works without the font (browser falls back), so a missing
    // asset never blocks the overlay from serving.
    try {
      _font = (await rootBundle.load(
        'assets/fonts/GurbaniAkharHeavyTrue.ttf',
      )).buffer.asUint8List();
    } catch (_) {
      _font = null;
    }
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true)
      ..listen(_handle);
  }

  Future<void> _handle(HttpRequest req) async {
    if (req.uri.path == '/ws') {
      final ws = await WebSocketTransformer.upgrade(req);
      _clients.add(ws);
      ws.add(_last); // catch the new page up
      ws.done.then((_) => _clients.remove(ws)).ignore();
      return;
    }
    if (req.uri.path == '/font.ttf' && _font != null) {
      req.response
        ..headers.contentType = ContentType('font', 'ttf')
        ..add(_font!);
      await req.response.close();
      return;
    }
    req.response
      ..headers.contentType = ContentType.html
      ..write(overlayPageHtml);
    await req.response.close();
  }

  /// Push the current line to every connected page.
  void showLine({
    required String gurmukhi,
    required String background,
    String? english,
    String? punjabi,
    String? roman,
    bool larivaar = false,
    bool vishraam = true,
    double fontScale = 1.0,
  }) {
    _last = jsonEncode({
      'g': gurmukhi,
      'en': english,
      'pa': punjabi,
      'roman': roman,
      'bg': background,
      'lv': larivaar,
      'vr': vishraam,
      'fs': fontScale,
    });
    for (final c in [..._clients]) {
      try {
        c.add(_last);
      } catch (_) {
        _clients.remove(c);
      }
    }
  }

  Future<void> stop() async {
    // Iterate a copy - closing a socket fires its done handler, which removes it
    // from _clients mid-loop.
    for (final c in [..._clients]) {
      await c.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }
}

/// The overlay page. Cream Gurbani in GurbaniAkhar (served from /font.ttf) over
/// the selected background, with Punjabi / English / roman beneath - matching the
/// in-app display pane. Fonts are sized in vh so text scales with the screen.
///
/// Each output picks its own content with a `?show=` query param, e.g.
/// `…/?show=gurmukhi,punjabi` for a minimal projector vs `…/?show=gurmukhi,
/// punjabi,english,roman` for a full operator-style output. No param = show
/// everything that has content. This is how one overlay differs from another.
const overlayPageHtml = '''
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
@font-face{font-family:GurbaniAkhar;src:url('/font.ttf');font-weight:800}
html,body{margin:0;height:100%;overflow:hidden;background:#0B1E3B}
#stage{height:100vh;display:flex;flex-direction:column;align-items:center;
  justify-content:center;text-align:center;padding:4vh 6vw;box-sizing:border-box}
#g{font-family:GurbaniAkhar;color:#FBF3E3;font-weight:800;line-height:1.6;
  font-size:7vh;margin:0}
#pa{font-family:GurbaniAkhar,system-ui,sans-serif;color:#FBF3E3;
  font-size:3.4vh;line-height:1.5;margin:2.6vh 0 0}
#en{color:rgba(251,243,227,.86);font-family:system-ui,sans-serif;
  font-size:3.2vh;line-height:1.4;margin:2vh 0 0}
#r{color:#F0B429;font-family:system-ui,sans-serif;font-size:2.6vh;margin:2vh 0 0}
.empty #g{opacity:.35}
</style></head><body>
<div id="stage"><p id="g">ੴ</p><p id="pa"></p><p id="en"></p><p id="r"></p></div>
<script>
var g=document.getElementById('g'),pa=document.getElementById('pa'),
    en=document.getElementById('en'),r=document.getElementById('r'),
    stage=document.getElementById('stage');
// Which content this output renders. ?show=gurmukhi,punjabi -> only those.
// No param -> everything with content.
var SHOW=(function(){
  var p=new URLSearchParams(location.search).get('show');
  return p?p.split(',').map(function(s){return s.trim()}):null;
})();
function allow(k){return !SHOW||SHOW.indexOf(k)>=0;}
// Build the Gurmukhi with vishraam colouring + larivaar - mirrors gurmukhi_text.dart:
// strip the embedded ; , . pause marks, colour the pause word when vishraam is on.
function bake(line,larivaar,vishraam){
  var words=line.split(/\\s+/).filter(Boolean),html='',sep=larivaar?'':' ';
  for(var i=0;i<words.length;i++){
    var w=words[i],c='';
    if(w.slice(-1)===';'){if(vishraam)c='#F0B429';}
    else if(w.slice(-1)===','){if(vishraam)c='rgba(251,243,227,.55)';}
    w=w.replace(/[;,.]/g,'');
    if(!w)continue;
    var esc=w.replace(/&/g,'&amp;').replace(/</g,'&lt;');
    html+=c?'<span style="color:'+c+'">'+esc+'</span>':esc;
    if(i<words.length-1)html+=sep;
  }
  return html||'ੴ';
}
function line(el,key,text){
  el.textContent=text||'';
  el.style.display=(allow(key)&&text)?'':'none';
}
function render(d){
  document.body.style.background=d.bg||'#0B1E3B';
  var fs=d.fs||1;
  g.style.fontSize=(7*fs)+'vh'; pa.style.fontSize=(3.4*fs)+'vh';
  en.style.fontSize=(3.2*fs)+'vh'; r.style.fontSize=(2.6*fs)+'vh';
  g.innerHTML=(allow('gurmukhi')&&d.g)?bake(d.g,d.lv,d.vr!==false):'';
  g.style.display=allow('gurmukhi')?'':'none';
  stage.className=d.g?'':'empty';
  line(pa,'punjabi',d.pa);
  line(en,'english',d.en);
  line(r,'roman',d.roman);
}
function connect(){
  var ws=new WebSocket('ws://'+location.host+'/ws');
  ws.onmessage=function(e){try{render(JSON.parse(e.data))}catch(x){}};
  ws.onclose=function(){setTimeout(connect,1000)};
}
connect();
</script></body></html>
''';
