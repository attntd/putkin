import json, os, pathlib, resource, subprocess, sys, tempfile
sys.path.insert(0, '/home/attntd/projects/putkin/scripts')
from _common import ROOT, isolated_environment, stop_process_group, tool
output = ROOT / 'docs/evidence/12-wayland-attempt.log'
with tempfile.TemporaryDirectory(prefix='pk-wayland-') as directory:
    base = pathlib.Path(directory)
    env = isolated_environment(directory)
    config = base / 'hyprland.conf'
    config.write_text('monitor = ,1920x1080@60,0x0,1\ndebug {\n disable_logs = false\n enable_stdout_logs = true\n}\n')
    command = [tool('bwrap'), '--unshare-all', '--die-with-parent', '--ro-bind', '/', '/', '--dev', '/dev', '--proc', '/proc', '--tmpfs', '/run', '--tmpfs', '/tmp', '--bind', directory, directory, tool('dbus-run-session'), '--', tool('Hyprland'), '--config', str(config)]
    # No host display, buses, /dev/dri or input nodes are exposed. No shell is started.
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    with output.open('w') as log:
        log.write('Private XDG, D-Bus, /dev, /run, /tmp and network; no shell, hardware or PAM.\n')
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
