import sys, tempfile, subprocess
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from _common import ROOT, isolated_environment, tool, stop_process_group, qml_errors
with tempfile.TemporaryDirectory(prefix='pk-material-') as directory:
    root = Path(directory)
    env = isolated_environment(directory)
    env.update(HOME=directory, PUTKIN_SCENARIO='trayMenu', PUTKIN_PREVIEW_WIDTH='1000', PUTKIN_PREVIEW_HEIGHT='700', PUTKIN_SCREENSHOT=str(root/'proof.png'))
    for name in ('core', 'services', 'components', 'modules', 'assets', 'preview'):
        (root/name).symlink_to(ROOT/name)
    (root/'proof.qml').write_text('''import QtQuick
import Quickshell
import "preview"
import "services"
ShellRoot {
    MockLauncherBackend {
        id: backend
        applications: [
            {id: "tether-gtk", name: "Tether", genericName: "Synchronizacja urządzeń", icon: "tether"},
            {id: "signal", name: "Signal", genericName: "Komunikator", icon: "signal-desktop"},
            {id: "kitty", name: "Kitty", genericName: "Terminal", icon: "kitty"},
            {id: "dolphin", name: "Dolphin", genericName: "Menedżer plików", icon: "org.kde.dolphin"},
            {id: "zen", name: "Zen Browser", genericName: "Przeglądarka", icon: "zen-browser"}
        ]
        history: []
    }
    LauncherService { id: launcher; backend: backend }
    MockTray {
        id: tray
        openEntry.icon: "document-open"
        Component.onCompleted: {
            reset(2);
            items.values[1].objectName = "tether-gtk"; items.values[1].title = "Tether";
            items.values[0].objectName = "Signal_status_icon_1";
            items.values[0].title = "Signal";
        }
    }
    PanelPreviewWindow { launcher: launcher; tray: tray; trayMenuComponent: tray.menuComponent }
    Timer { interval: 200; running: true; onTriggered: launcher.edit(":a ") }
}
''')
    with tempfile.TemporaryFile(mode='w+') as log:
        process=subprocess.Popen([tool('dbus-run-session'),'--',tool('quickshell'),'--no-color','--path',str(root/'proof.qml')],env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            process.wait(timeout=4)
        except subprocess.TimeoutExpired:
            pass
        finally:
            stop_process_group(process)
        log.seek(0); output=log.read()
    (ROOT/'docs/evidence/material-tray-preview.log').write_text(output)
    print(output)
    assert not qml_errors(output, allow_offscreen_masks=True)
    assert 'PUTKIN_SCREENSHOT_SAVED' in output
    (ROOT/'docs/evidence/material-tray-preview.png').write_bytes((root/'proof.png').read_bytes())
