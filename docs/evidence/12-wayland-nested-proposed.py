# Initially rejected; then explicitly approved and executed on 2026-09-16.
# Historical 12-second probe: startup passed, but the event socket path was too long.
import json, os, pathlib, resource, subprocess, sys, tempfile
sys.path.insert(0, '/home/attntd/projects/putkin/scripts')
from _common import ROOT, isolated_environment, stop_process_group, tool
output = ROOT / 'docs/evidence/12-wayland-nested-attempt.log'
with tempfile.TemporaryDirectory(prefix='pk-wayland-') as directory:
    base = pathlib.Path(directory)
    env = isolated_environment(directory)
    config = base / 'hyprland.conf'
    config.write_text('monitor = ,1920x1080@60,0x0,1\ndebug {\n disable_logs = false\n enable_stdout_logs = true\n}\n')
    command = [tool('bwrap'), '--unshare-all', '--die-with-parent', '--ro-bind', '/', '/', '--dev', '/dev', '--proc', '/proc', '--tmpfs', '/run', '--tmpfs', '/tmp', '--bind', directory, directory, tool('dbus-run-session'), '--', tool('Hyprland'), '--config', str(config)]
    parent_socket = pathlib.Path(os.environ['XDG_RUNTIME_DIR']) / os.environ['WAYLAND_DISPLAY']
    command[command.index(tool('dbus-run-session')):command.index(tool('dbus-run-session'))] = ['--ro-bind', str(parent_socket), str(base / 'runtime/parent-wayland'), '--dev-bind', '/dev/dri/renderD128', '/dev/dri/renderD128']
    env['WAYLAND_DISPLAY'] = 'parent-wayland'
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    with output.open('w') as log:
        log.write('Private nested compositor, XDG, D-Bus, /dev, /run, /tmp and network. Only parent Wayland socket and renderD128 exposed; no shell, modesetting node, hardware services or PAM.\n')
        log.write(json.dumps(command) + '\n'); log.flush()
        p = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = p.wait(timeout=12)
        except subprocess.TimeoutExpired:
            code = None
        finally:
            stop_process_group(p)
        log.write(f'\nExit: {code}; render nodes available on host: {pathlib.Path("/dev/dri").exists()}\n')
        for file in (base/'runtime/hypr').glob('*/hyprland.log'):
            log.write(file.read_text(errors='replace'))
    print(output)
