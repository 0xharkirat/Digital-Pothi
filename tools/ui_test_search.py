#!/usr/bin/env python3
"""Drive the running Gurbani Live app through the search-parity UI flows via
marionette_mcp (stdio JSON-RPC). Prints one PASS/FAIL line per step."""
import json
import subprocess
import sys
import time

VM_URI = sys.argv[1] if len(sys.argv) > 1 else 'ws://127.0.0.1:58720/HDEGYZbkfC8=/ws'

p = subprocess.Popen(['/Users/hark/.pub-cache/bin/marionette_mcp'],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL, text=True)
_id = 0

def rpc(method, params=None):
    global _id
    _id += 1
    p.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': _id, 'method': method,
                              'params': params or {}}) + '\n')
    p.stdin.flush()
    while True:
        line = p.stdout.readline()
        if not line:
            raise RuntimeError('server closed')
        msg = json.loads(line)
        if msg.get('id') == _id:
            return msg

def call(tool, args=None):
    r = rpc('tools/call', {'name': tool, 'arguments': args or {}})
    if 'error' in r:
        return True, json.dumps(r['error'])
    res = r.get('result', {})
    texts = [c.get('text', '') for c in res.get('content', []) if c.get('type') == 'text']
    return res.get('isError', False), '\n'.join(texts)

def elements():
    _, text = call('get_interactive_elements')
    return text

def pick_mode(label):
    """Open the type dropdown (best-effort - the closed button also exposes its
    items offstage, so the item tap works either way), then tap the item."""
    call('tap', {'key': 'search_type'})
    time.sleep(0.7)
    err, out = call('tap', {'text': label})
    time.sleep(0.7)
    return not err, out

results = []
def check(name, ok, detail=''):
    results.append((name, ok))
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail[:140]}]" if detail and not ok else ''))

rpc('initialize', {'protocolVersion': '2024-11-05', 'capabilities': {},
                   'clientInfo': {'name': 'search-ui-test', 'version': '2'}})
p.stdin.write(json.dumps({'jsonrpc': '2.0', 'method': 'notifications/initialized'}) + '\n')
p.stdin.flush()
err, out = call('connect', {'uri': VM_URI})
check('connect to app', not err, out)
if err:
    sys.exit(1)
call('hot_restart')
time.sleep(5)  # fresh state: no shabad open until Enter opens one

# 1. English mode, search "beloved" -> results with translation snippets.
ok, detail = pick_mode('Full word (English)')
check('pick Full word (English)', ok, detail)
call('enter_text', {'key': 'search_field', 'input': 'beloved'})
time.sleep(0.9)
els = elements()
check('English search shows results', 'Ang ' in els and 'No results' not in els, els[:400])

# 2. Open the first result by tapping its tile (the Enter/onSubmitted path is
# covered by the widget test via a real TextInputAction - marionette's
# synthetic hardware Enter bypasses the IME so it can't drive onSubmitted).
first = next((l for l in elements().split('\n')
              if 'Type: RichText, Text: "Ang ' in l), '')
tile_text = first.split('Text: "', 1)[1].split('", ')[0] if first else ''
err, out = call('tap', {'text': tile_text}) if tile_text else (True, 'no tile')
time.sleep(0.9)
els = elements()
check('tapping first result opens the shabad (toolbar visible)',
      'Previous line' in els and 'Next line' in els, out + ' | ' + els[:300])

# 3. Ang mode: 917 lists the page (Anand Sahib's ang).
ok, detail = pick_mode('Ang')
check('pick Ang mode', ok, detail)
call('enter_text', {'key': 'search_field', 'input': '917'})
time.sleep(0.9)
els = elements()
check('Ang 917 lists the page', 'Ang 917' in els, els[:400])

# 4. Back to first-letter; query has results.
ok, detail = pick_mode('First letter (anywhere)')
check('back to First letter (anywhere)', ok, detail)
call('enter_text', {'key': 'search_field', 'input': 'ssnh'})
time.sleep(0.9)
check('first-letter query has results', 'Ang ' in elements())


def open_first_result():
    first = next((l for l in elements().split('\n')
                  if 'Type: RichText, Text: "Ang ' in l), '')
    tile = first.split('Text: "', 1)[1].split('", ')[0] if first else ''
    if tile:
        call('tap', {'text': tile})
    time.sleep(0.9)
    return bool(tile)


# 5. Intelligent spacebar: open a shabad AT its rahao line (first letters
# 'ajvdkkd' hit exactly one line, Dhanasari M1's rahao), so home = rahao.
# Space is a raw key on the presenter Focus, so press_key reaches it (unlike
# the TextField IME path). The displayed line is detected by counting the
# dump's occurrences of the rahao text: the display pane adds one copy on top
# of the shabad row + badge, so home <-> away moves the count by one.
call('enter_text', {'key': 'search_field', 'input': 'ajvdkkd'})
time.sleep(0.9)
check('rahao line found + home affordance shown',
      open_first_result() and 'Home line' in elements())
at_home = elements().count('ਰਹਾਉ')
call('press_key', {'key': 'space'})
time.sleep(0.8)
moved = elements().count('ਰਹਾਉ')
check('space resumes the antara run (off the rahao)', moved < at_home,
      f'home count {at_home}, after space {moved}')
back = moved
for _ in range(3):
    if back == at_home:
        break
    call('press_key', {'key': 'space'})
    time.sleep(0.8)
    back = elements().count('ਰਹਾਉ')
check('space walks the couplet then snaps back home', back == at_home,
      f'never returned: {back} != {at_home}')

print('---')
failed = [n for n, ok in results if not ok]
print(f"{len(results) - len(failed)}/{len(results)} steps passed" + (f"; FAILED: {failed}" if failed else ''))
call('disconnect')
p.terminate()
sys.exit(1 if failed else 0)
