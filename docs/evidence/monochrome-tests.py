import sys, subprocess, tempfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from _common import isolated_environment, tool, ROOT, qml_errors, stop_process_group
for name in ['launcher', 'status']:
    with tempfile.TemporaryDirectory(prefix='pk-mono-') as d:
        env=isolated_environment(d); env['HOME']=d; env['QT_SCALE_FACTOR']='1.5' if '--scale' in sys.argv else '1'
        process=subprocess.Popen([tool('dbus-run-session'),'--',tool('qmltestrunner'),'-input',str(ROOT/f'tests/qml/tst_{name}.qml'),'-import',str(ROOT)] + ([('Launcher::test_application_icons' if name == 'launcher' else 'BatteryTray::test_tray_icon_center_and_signal_color')] if '--focused' in sys.argv else []),env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,start_new_session=True)
        try: output,_=process.communicate(timeout=100)
        finally: stop_process_group(process)
        (ROOT/f'docs/evidence/monochrome-{name}-qml{"-scale" if "--scale" in sys.argv else ""}.log').write_text(output)
        print(output[-8000:],flush=True)
        if process.returncode or qml_errors(output): sys.exit(1)
