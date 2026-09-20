"""Approved 12-second compositor-only probe with short private IPC paths.

No Putkin, screenshot client, input client, hardware services or PAM launched.
The sole additional check is a read-only monitors query to the private socket.
"""
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from _common import ROOT, isolated_environment, stop_process_group, tool

output = ROOT/'docs/evidence/12-wayland-short-runtime.log'
report = {'scope': '12-second compositor-only probe; no Putkin UI or hardware/session actions'}
resource.setrlimit(resource.RLIMIT_CORE, (0,0))
with tempfile.TemporaryDirectory(prefix='pw-') as directory:
    base = Path(directory)
    env = isolated_environment(directory)
    (base/'r').mkdir(mode=0o700)
    env['XDG_RUNTIME_DIR'] = str(base/'r')
    env['WAYLAND_DISPLAY'] = 'parent-wayland'
    parent = Path(os.environ['XDG_RUNTIME_DIR']) / os.environ['WAYLAND_DISPLAY']
    config = base/'hyprland.conf'
    config.write_text('monitor = ,1920x1080@60,0x0,1\nxwayland {\n enabled = false\n}\ndebug {\n disable_logs = false\n enable_stdout_logs = true\n}\n')
    command = [tool('bwrap'), '--unshare-all', '--die-with-parent', '--ro-bind', '/', '/',
               '--dev', '/dev', '--proc', '/proc', '--tmpfs', '/run', '--tmpfs', '/tmp', '--bind', directory, directory,
               '--ro-bind', str(parent), str(base/'r/parent-wayland'), '--dev-bind', '/dev/dri/renderD128', '/dev/dri/renderD128',
               tool('dbus-run-session'), '--', tool('Hyprland'), '--config', str(config)]
    with output.open('w') as log:
        log.write(json.dumps(command)+'\n'); log.flush()
        start = time.monotonic()
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            while time.monotonic() - start < 9 and process.poll() is None:
                sockets = list((base/'r/hypr').glob('*/.socket.sock'))
                if sockets:
                    path = sockets[0]
                    signature = path.parent.name
                    reply = subprocess.run([tool('hyprctl'), '-i', signature, '-j', 'monitors'], env=env, capture_output=True, text=True, timeout=1)
                    if reply.returncode == 0 and reply.stdout.strip().startswith('['):
                        monitors = json.loads(reply.stdout)
                        if monitors:
                            report['monitors'] = monitors
                            report['event_socket_exists'] = (path.parent/'.socket2.sock').is_socket()
                            report['event_socket_path_bytes'] = len(os.fsencode(path.parent/'.socket2.sock'))
                            break
                time.sleep(0.1)
            remaining = max(0.01, 12 - (time.monotonic() - start))
            try:
                process.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                report['alive_at_deadline'] = True
            report['duration_before_shutdown_s'] = time.monotonic() - start
        finally:
            stop_process_group(process)
        report['wrapper_exit_after_shutdown'] = process.returncode
    report['private_directory'] = directory
    report['result'] = 'PASS compositor and private IPC' if report.get('monitors') and report.get('event_socket_exists') and report.get('alive_at_deadline') else 'FAIL'
    output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    if report['result'].startswith('FAIL'): sys.exit(1)
