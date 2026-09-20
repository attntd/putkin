import sys, tempfile, subprocess
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from _common import ROOT, isolated_environment, tool, stop_process_group, qml_errors
with tempfile.TemporaryDirectory(prefix='pk-papirus-') as directory:
    root = Path(directory)
    env = isolated_environment(directory)
    env.update(HOME=directory, QT_QPA_PLATFORMTHEME='qt6ct', PUTKIN_SCENARIO='launcher', PUTKIN_PREVIEW_WIDTH='1000', PUTKIN_PREVIEW_HEIGHT='700', PUTKIN_SCREENSHOT=str(root/'proof.png'))
    config=Path(env['XDG_CONFIG_HOME'])/'qt6ct'; config.mkdir()
    (config/'qt6ct.conf').write_text('[Appearance]\nicon_theme=Papirus-Dark\n')
    icons=Path(env['XDG_DATA_HOME'])/'icons'; icons.mkdir()
    for name in ('Papirus', 'Papirus-Dark'):
        (icons/name).symlink_to(Path('/usr/share/icons')/name)
    for name in ('core', 'services', 'components', 'modules', 'assets', 'preview'):
        (root/name).symlink_to(ROOT/name)
    (root/'proof.qml').write_text('''//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell
import "preview"
import "services"
ShellRoot {
    MockLauncherBackend {
        id: backend
        applications: [
            {id: "kitty", name: "Kitty", genericName: "Terminal", icon: "kitty"},
            {id: "dolphin", name: "Dolphin", genericName: "Menedżer plików", icon: "org.kde.dolphin"},
            {id: "zen", name: "Zen Browser", genericName: "Przeglądarka", icon: "zen-browser"}
        ]
        history: []
        iconSources: ({"kitty": Quickshell.iconPath("kitty", true), "org.kde.dolphin": Quickshell.iconPath("org.kde.dolphin", true), "zen-browser": Quickshell.iconPath("zen-browser", true)})
    }
    LauncherService { id: launcher; backend: backend }
    PanelPreviewWindow { launcher: launcher }
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
    (ROOT/'docs/evidence/launcher-icons-preview.log').write_text(output)
    print(output)
    assert not qml_errors(output, allow_offscreen_masks=True)
    assert 'PUTKIN_SCREENSHOT_SAVED' in output
    (ROOT/'docs/evidence/launcher-icons-preview.png').write_bytes((root/'proof.png').read_bytes())
