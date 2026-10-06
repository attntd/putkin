import os, sys, subprocess, tempfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from _common import ROOT, isolated_environment, tool, qml_errors, stop_process_group
scale = os.environ.get('PUTKIN_TEST_SCALE', '1')
with tempfile.TemporaryDirectory(prefix='pk-signal-gui-') as tmp:
    env = isolated_environment(tmp)
    env['QT_SCALE_FACTOR'] = scale
    env['QT_LOGGING_TO_CONSOLE'] = '1'
    cmd = [tool('dbus-run-session'), '--', '/usr/lib/qt6/bin/qmltestrunner', '-input', str(ROOT / sys.argv[1]), '-import', str(ROOT), *sys.argv[2:]]
    process = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=180)
    finally:
        stop_process_group(process)
    print(output, end=''); print('QtTest exit:', process.returncode, flush=True)
    sys.exit(int(process.returncode != 0 or bool(qml_errors(output))))
