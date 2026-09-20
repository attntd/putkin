#!/usr/bin/env python3
"""Explicit test-only owner substitution; production has no environment bypass."""

import json
import os
from pathlib import Path
import signal
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services"))
from night_light import Client, bounded_command, run, socket_path

runtime = Path(os.environ["XDG_RUNTIME_DIR"])
assert (runtime.parent / "night-light-test-only").is_file()
if (runtime.parent / "hang-helper").exists():
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(30)
if (runtime.parent / "hang-command").exists():
    bounded_command([sys.executable, "-c", "import os,sys,time; from pathlib import Path; Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(30)", str(runtime.parent / "command-pid")])
print(json.dumps(run(sys.argv[1:], Client(socket_path(), owner_check=lambda pid: None))), flush=True)
