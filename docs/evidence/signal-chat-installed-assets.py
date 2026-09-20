"""Verify the unread reader against the installed Signal application's assets.

Reads application code/assets only. No Signal profile or messages are accessed.
Extracted PNGs and the generated QML probe stay in a temporary directory.
"""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import sys
import tempfile

ROOT = Path('/home/attntd/projects/putkin')
BUILD = Path('/tmp/putkin-signal-chat-validation')
EVIDENCE = ROOT / 'docs/evidence'
ASAR = Path('/usr/lib/signal-desktop/resources/app.asar')

with tempfile.TemporaryDirectory(prefix='pk-signal-assets-') as directory:
    directory = Path(directory)
    assets = {}
    with ASAR.open('rb') as archive:
        header = struct.unpack('<4I', archive.read(16))
        tree = json.loads(archive.read(header[3]))
        tray = tree['files']['images']['files']['tray-icons']['files']
        for group, folder in tray.items():
            for name, entry in folder['files'].items():
                archive.seek(8 + header[1] + int(entry['offset']))
                data = archive.read(entry['size'])
                assert len(data) == entry['size']
                (directory / name).write_bytes(data)
                assets[f'{group}/{name}'] = hashlib.sha256(data).hexdigest()
    rows = []
    for size in (16, 32, 48, 256):
        base = directory / f'signal-tray-icon-{size}x{size}-base.png'
        for count in [*range(1, 10), '9+']:
            alert = directory / f'signal-tray-icon-{size}x{size}-alert-{count}.png'
            assert base.exists() and alert.exists()
            rows.append({'tag': f'{size}px-{count}', 'base': base.as_uri(), 'alert': alert.as_uri()})
    qml = '''import QtQuick
import QtTest
import "SERVICES"
Item {
    width: 100; height: 100
    SignalTrayState { id: state }
    TestCase {
        name: "InstalledSignalIcons"
        when: windowShown
        function init() { failOnWarning(/.*/); state.source = ""; }
        function test_badge_data() { return ROWS; }
        function test_badge(data) {
            state.source = data.alert;
            tryCompare(state, "unread", true);
            state.source = data.base;
            tryCompare(state, "unread", false);
        }
    }
}
'''.replace('SERVICES', (BUILD / 'services').as_uri()).replace('ROWS', json.dumps(rows))
    probe = directory / 'tst_signal.qml'
    probe.write_text(qml)
    log = EVIDENCE / 'signal-chat-installed-assets.log'
    result = subprocess.run([sys.executable, str(BUILD / 'scripts/test-icons'),
        '--file', str(probe), '--scale', '1.5', '--log', str(log)])
    report = {'signal_package': subprocess.check_output(['pacman', '-Q', 'signal-desktop'], text=True).strip(),
        'assets': assets, 'transition_cases': len(rows), 'scale': 1.5,
        'returncode': result.returncode, 'log': str(log), 'private_profile_accessed': False}
    (EVIDENCE / 'signal-chat-installed-assets.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(result.returncode)
