"""S11 real Wayland surfaces/input, isolated synthetic bridge and settings FileView."""
import json
from pathlib import Path
import subprocess
import time
from signal_acceptance import Driver, eventually, prepare, event, tool, ROOT
from _common import qml_errors, runtime_log
from test_signal_history import OWN
from test_signal_interactions import reaction, edit
from test_signal_receipts import receipt
from test_signal_media import png, attachment_event


def run(environment, base, output, first, hypr, launch):
    assert Path('/proc/1/comm').read_text().strip() == 'bwrap'
    env = dict(environment, PUTKIN_SIGNAL_NATIVE='1')
    seeded = prepare(env, base, count=120)
    app, log = launch([tool('quickshell'), '--no-color', '--path', str(ROOT/'signal-acceptance-test.qml')], 'signal', env)
    d = Driver(env, base, app, log, seeded)
    captures = []
    def capture(name, monitor=first):
        if d.state().get('loaded'):
            d.wait(lambda s: s.get('presentationOpacity') == 1, 'fully presented frame before capture')
        hypr('dismissnotify')
        time.sleep(.25)
        path = output/(name+'.png')
        assert monitor.startswith('HEADLESS-')
        subprocess.run([str(base/'grim'), '-o', monitor, str(path)], env=env, capture_output=True, check=True, timeout=8)
        captures.append(path.name)
    def keys(*values):
        args=[tool('wtype')]
        for key in values: args += ['-k', key]
        subprocess.run(args, env=env, capture_output=True, check=True, timeout=5)
    def text(value): subprocess.run([tool('wtype'), '--', value], env=env, capture_output=True, check=True, timeout=5)
    def focus(title):
        client=eventually(lambda: hypr('clients',data=True),lambda cs:any(c.get('title')==title for c in cs),'window mapped')
        address=next(c['address'] for c in client if c.get('title')==title)
        hypr('dispatch','hl.dsp.focus({window="address:'+address+'"})')
    d.wait(lambda s:s.get('state')=='ready' and s.get('settingsReady') and not s.get('pending'),'native startup')
    hypr('dispatch','hl.dsp.focus({monitor='+json.dumps(first)+'})')
    d.ipc('monitor', first)
    d.ipc('notificationTimeout', 30000)
    d.receive(event(timestamp=seeded['stamp'],body='S11: tekst <b>dosłownie</b> 🐈'))
    d.wait(lambda s:len(s.get('history',[]))==1 and not s['pending'],'native toast')
    assert not d.state()['loaded']
    d.ipc('coverMessages')
    focus('Syntetyczne inne okno S11')
    text('hjkl')
    d.wait(lambda s:s.get('coverText')=='hjkl','passive toast does not steal keys')
    def notice_state():
        state = json.loads(d.ipc('notificationSnapshot'))
        (output/'notification-last.json').write_text(json.dumps(state, indent=2)+'\n')
        return state
    def notice_focus(name):
        try:
            return eventually(notice_state, lambda s: s['focus'] == name, 'notification focus on '+name, 3)
        except AssertionError:
            (output/'notification-focus-failure.json').write_text(json.dumps(notice_state(), indent=2)+'\n')
            capture('notification-focus-failure')
            raise
    eventually(notice_state, lambda s: len(s['actions']) == 2, 'native action delegates ready')
    time.sleep(.25)
    assert d.ipc('toastFocus') == first
    notice_focus('notificationSelection')
    keys('l'); notice_focus('notificationMute')
    keys('j')
    (output/'notification-action-before.json').write_text(json.dumps(notice_state(), indent=2)+'\n')
    capture('notification-action-navigation')
    notice_focus('notificationAction-0')
    keys('l'); notice_focus('notificationAction-1')
    keys('k'); notice_focus('notificationMute')
    keys('l'); notice_focus('notificationClose')
    keys('j'); notice_focus('notificationAction-0')
    keys('k'); notice_focus('notificationClose')
    keys('h', 'h'); notice_focus('notificationSelection')
    d.check('native Signal toast navigates frame, both header buttons, Open and Reply with hjkl')
    keys('l', 'j', 'l', 'Return'); notice_focus('notificationReplyEditor')
    assert d.ipc('replyOpen',0)=='true'
    d.wait(lambda s:s.get('reply') and s['reply']['ready'],'native reply')
    time.sleep(.3)
    text('hjkl Zażółć 🐈')
    d.wait(lambda s:s['reply']['text']=='hjkl Zażółć 🐈','unicode input into actual reply editor')
    subprocess.run([tool('wtype'),'-M','shift','-k','Return','-m','shift'],env=env,check=True,capture_output=True,timeout=5)
    text('drugi wiersz')
    d.wait(lambda s:'\n' in s['reply']['text'],'Shift Enter newline')
    assert not d.records('send')
    initial=d.state()
    assert d.ipc('appearance','preview','#f5c2e7','#a6e3a1')=='true'
    d.wait(lambda s:s['accent']=='#f5c2e7' and s['secondary']=='#a6e3a1','two accent preview')
    assert d.state()['replyScreen'] == first
    capture('reply-preview')
    d.ipc('appearance','cancel','','')
    d.wait(lambda s:s['accent']==initial['accent'] and s['secondary']==initial['secondary'],'accent cancellation')
    d.ipc('appearance','save','#94e2d5','#fab387')
    d.wait(lambda s:s['accent']=='#94e2d5' and s['secondary']=='#fab387' and not s['settingsSaving'],'accent commit')
    assert 'drugi wiersz' in d.state()['reply']['text']
    capture('reply-saved')
    keys('Escape')
    d.wait(lambda s:not s['reply']['editing'],'reply escape')
    # Escape collapses editor first, then leaves stack navigation.
    keys('Escape')
    d.wait(lambda s:s.get('coverActive') and not s['replyScreen'], 'previous app regains native keyboard focus')
    text('x')
    d.wait(lambda s:s.get('coverText')=='hjklx','focus returned to previous app')
    d.check('native passive toast, actual quick-reply keyboard/Unicode/Shift+Enter/Escape, focus return, two accents preview/cancel/save preserve draft')
    d.ipc('centerWindow', True)
    focus('Centrum testowe S11')
    d.ipc('centerFocus')
    notice_focus('notificationDnd')
    keys('j', 'l'); notice_focus('notificationMute')
    keys('j'); notice_focus('notificationAction-0')
    keys('l'); notice_focus('notificationAction-1')
    keys('k'); notice_focus('notificationMute')
    keys('l'); notice_focus('notificationClose')
    keys('j', 'k'); notice_focus('notificationClose')
    keys('h', 'h'); notice_focus('notificationSelection')
    capture('notification-center-navigation')
    d.ipc('centerWindow', False)
    d.check('native archived Signal card navigates both button rows and returns to its frame')
    assert d.ipc('openList', first) == 'true'
    focus('Wiadomości')
    d.wait(lambda s: s.get('listFocused'), 'ordinary open focuses conversation list')
    keys('j', 'k', 'Return')
    d.wait(lambda s: s.get('focus') == 'messageEditor' and s.get('draftReady'), 'Enter opens selected conversation and focuses composer')
    keys('Escape')
    d.wait(lambda s: s.get('listFocused') and s.get('loaded'), 'Escape returns to list without closing window')
    keys('l')
    d.wait(lambda s: s.get('focus') == 'messageEditor', 'l opens conversation')
    d.close()
    # Follow the same Open action used by a notification click.
    expected = d.state()['history'][0]['messageReference']['conversationId']
    assert d.ipc('notificationOpen', 0) == 'true'
    focus('Wiadomości')
    d.wait(lambda s: s.get('focus') == 'messageEditor' and s.get('selected', {}).get('conversationId') == expected,
           'notification selects its conversation and focuses composer')
    d.check('ordinary open focuses list; native j/k/Enter/l/Escape; notification action routes to composer in recreated window')
    # Synthetic content covers outgoing accent, media labels and the shared
    # reaction/time footer without capturing a real user's conversation.
    stamp = seeded['stamp'] + 200
    d.receive(event('sent-sync', timestamp=stamp, body='Wiadomość testowa z telefonu. Do zobaczenia!'))
    d.receive(reaction(target=stamp, stamp=stamp+1, author=OWN))
    d.wait(lambda s: any(json.loads(r['reactionsJson']) for r in s.get('rows', [])) and not s.get('pending'), 'synthetic outgoing reaction')
    d.receive(edit(target=stamp, stamp=stamp+3, body='Wiadomość testowa z telefonu. Do zobaczenia!', phone=True))
    d.receive(receipt('read', [stamp+3], when=stamp+4))
    d.wait(lambda s: any(r['edited'] and r['statusCode'] == 'read' for r in s.get('rows', [])), 'edited and read outgoing footer')
    source = d.db.parent/'cli/attachments/ui-layout.png'
    source.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    png(source, width=240, height=100)
    d.receive(attachment_event(source, 'image/png', timestamp=stamp+2, name='sent-sync'))
    try:
        d.wait(lambda s: any(a.get('state') == 'ready' for row in s.get('mediaRows', []) for a in row), 'synthetic outgoing media')
    except AssertionError:
        state = d.state()
        print('Synthetic media diagnostic:', {'state': state.get('state'), 'lastError': state.get('lastError'),
            'media': [{'state': a.get('state'), 'errorCode': a.get('errorCode')} for row in state.get('mediaRows', []) for a in row]}, flush=True)
        raise
    capture('messages-empty-composer')
    thumbnail = json.loads(d.ipc('controlGeometry', 'previewAttachment'))
    client = next(c for c in hypr('clients', data=True) if c['title'] == 'Wiadomości')
    x, y = client['at'][0] + thumbnail['x'] + thumbnail['width']/2, client['at'][1] + thumbnail['y'] + thumbnail['height']/2
    hypr('dispatch', 'hl.dsp.cursor.move({x=' + str(round(x)) + ',y=' + str(round(y)) + '})')
    subprocess.run([str(base/'click')], env=env, check=True, capture_output=True, timeout=5)
    d.wait(lambda s: s.get('mediaPreview'), 'native thumbnail click opens preview')
    capture('attachment-preview')
    keys('Escape')
    d.wait(lambda s: not s.get('mediaPreview') and s.get('focus') == 'previewAttachment', 'close preview restores thumbnail focus')
    d.check('native thumbnail click opens media with details/actions; Escape returns focus to thumbnail')
    d.ipc('editorFocus')
    d.wait(lambda s:s.get('focus')=='messageEditor','message editor focus')
    text('hjkl z okna')
    d.wait(lambda s:s['draftText']=='hjkl z okna','window normal text keys')
    capture('messages-large')
    subprocess.run([tool('wtype'),'-M','shift','-k','Return','-m','shift'],env=env,check=True,capture_output=True,timeout=5)
    text('Dłuższa wiadomość testowa. ' * 8)
    d.wait(lambda s:'\n' in s['draftText'], 'multiline composer')
    capture('messages-multiline')
    d.ipc('draft', 'hjkl z okna')
    d.wait(lambda s:s['draftText']=='hjkl z okna', 'restore short draft')
    d.ipc('showDetails', True)
    capture('conversation-details')
    d.ipc('showDetails', False)
    clients=hypr('clients',data=True)
    address=next(c['address'] for c in clients if c.get('title')=='Wiadomości')
    # Resize the real xdg-toplevel, not a mock Item.
    hypr('dispatch','hl.dsp.window.float({window="address:'+address+'",action="enable"})')
    hypr('dispatch','hl.dsp.window.resize({window="address:'+address+'",x=420,y=520})')
    d.wait(lambda s:s.get('geometry') and s['geometry']['width']<=500,'small native window')
    capture('messages-small')
    d.close()
    hypr('eval','hl.monitor({output='+json.dumps(first)+',mode="1920x1080@60",position="2000x0",scale=1.5})')
    eventually(lambda:hypr('monitors',data=True),lambda ms:any(m['name']==first and m['scale']==1.5 for m in ms),'fractional scale')
    d.open(monitor=first); focus('Wiadomości')
    monitor = next(m for m in hypr('monitors', data=True) if m['name'] == first)
    client = next(c for c in hypr('clients', data=True) if c['title'] == 'Wiadomości')
    assert client['at'][0] >= monitor['x'] and client['at'][1] >= monitor['y']
    assert client['at'][0] + client['size'][0] <= monitor['x'] + monitor['width'] / monitor['scale']
    assert client['at'][1] + client['size'][1] <= monitor['y'] + monitor['height'] / monitor['scale']
    capture('messages-scale-1.5')
    d.check('real large/small native window and scale 1.5 render correctly; hjkl remains text')
    d.close()
    known={m['name'] for m in hypr('monitors',data=True)}
    hypr('output','create','headless')
    ms=eventually(lambda:hypr('monitors',data=True),lambda ms:any(m['name'] not in known for m in ms),'second output')
    second=next(m['name'] for m in ms if m['name'] not in known)
    hypr('eval','hl.monitor({output='+json.dumps(second)+',mode="1920x1080@60",position="4000x0",scale=1})')
    d.wait(lambda s:any(m['name']==second for m in s.get('screens',[])),'Qt second screen')
    hypr('dispatch','hl.dsp.focus({monitor='+json.dumps(second)+'})')
    d.open(monitor=second); focus('Wiadomości')
    d.wait(lambda s:s['screen']==second,'requested second screen')
    target = next(m for m in hypr('monitors', data=True) if m['name'] == second)
    assert next(c for c in hypr('clients', data=True) if c['title'] == 'Wiadomości')['monitor'] == target['id']
    capture('messages-second-output',second)
    d.ipc('trace', 'before-hotplug')
    hypr('output','remove',second)
    d.wait(lambda s:all(m['name']!=second for m in s['screens']) and s['screen']!=second and s['loaded'],'hotplug fallback')
    d.ipc('trace', 'after-hotplug')
    assert d.state()['draftText']=='hjkl z okna'
    d.ipc('locked',True)
    d.wait(lambda s:not s['loaded'],'lock releases message surface')
    d.receive(event(timestamp=seeded['stamp']+1000,body='S11_LOCK_PRIVATE_MARKER'))
    d.wait(lambda s:not s['pending'] and any(r.get('body')=='Nowa wiadomość' for r in s['history']),'lock redaction')
    assert 'S11_LOCK_PRIVATE_MARKER' not in json.dumps(d.state()['history'])
    d.ipc('trace', 'locked')
    capture('locked-redacted')
    d.ipc('locked',False)
    d.check('second monitor routing, mixed scales and hotplug preserve draft; lock closes conversation and redacts new notification')
    assert not qml_errors(runtime_log(log)),runtime_log(log)
    generation=d.state()['generation'];d.ipc('reload')
    d.wait(lambda s:s.get('state')=='ready' and s.get('generation')!=generation and s.get('settingsReady'),'native hard reload')
    assert d.state()['accent']=='#94e2d5' and d.state()['secondary']=='#fab387'
    d.ipc('monitor', first)
    hypr('dispatch','hl.dsp.focus({monitor='+json.dumps(first)+'})')
    d.open(monitor=first);focus('Wiadomości')
    assert d.state()['draftText']=='hjkl z okna'
    target = next(m for m in hypr('monitors', data=True) if m['name'] == first)
    assert next(c for c in hypr('clients', data=True) if c['title'] == 'Wiadomości')['monitor'] == target['id']
    capture('messages-after-reload')
    d.close()
    d.check('native reload preserves committed accents/history/draft with one new receiver')
    result={'passed':True,'checks':d.checks,'captures':captures,'livePhone':False,
            'ime':'Unicode via wtype; preedit contract tested in Qt separately; physical IME engine remains S12'}
    (output/'signal-report.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
    d.ipc('quit');app.wait(timeout=8)
    assert not qml_errors(runtime_log(log)),runtime_log(log)
    return result
