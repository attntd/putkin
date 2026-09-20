#!/usr/bin/env python3
"""Private executable fixtures. Never connect to Wayland or a real clipboard."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

name = Path(sys.argv[0]).name
root = Path(os.environ['PUTKIN_LAUNCHER_FIXTURE'])
if name == 'wl-paste':
    mime = sys.argv[sys.argv.index('--type') + 1]
    fifo = root / (mime + '.fifo')
    command = sys.argv[sys.argv.index('--watch') + 1:]
    with os.fdopen(os.open(fifo, os.O_RDWR), 'r') as stream:
        for message in stream:
            data = (root / (mime + '.data')).read_bytes()
            env = dict(os.environ, CLIPBOARD_STATE=message.strip())
            subprocess.run(command, input=data, env=env, check=True)
elif name == 'wl-copy':
    (root / 'copied').write_bytes(sys.stdin.buffer.read())
    signal.pause()
else:
    with (root / 'actions.jsonl').open('a') as stream:
        stream.write(json.dumps(dict(tool=name, argv=sys.argv[1:], cwd=os.getcwd())) + '\n')
    if any('fail-open' in arg for arg in sys.argv):
        sys.exit(1)
