// Synthetic clients for the isolated compositor regression.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services"

ShellRoot {
    id: root
    property int tick: 0
    property bool secondVisible: false
    property bool updates: true
    Component.onCompleted: { if (Quickshell.env("PUTKIN_BORDERS_TEST") !== "1") Qt.quit(); }

    HyprlandAppearanceBackend { id: backend }
    WindowAppearanceService { backend: backend }
    Timer { interval: 80; running: root.updates; repeat: true; onTriggered: root.tick++ }

    Variants {
        model: Quickshell.screens
        // Quickshell 0.3.1 platform factory metadata, as in WallpaperWindow.
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            color: "#11111b"
        }
    }
    FloatingWindow {
        title: "Putkin border first"
        implicitWidth: 420; implicitHeight: 300; visible: true
        color: "#1e1e2e"
        Rectangle {
            x: 20; y: 0; width: parent.width - 40; height: 60
            color: root.tick % 2 ? "#313244" : "#585b70"
        }
    }
    FloatingWindow {
        id: second
        title: "Putkin border second"
        implicitWidth: 360; implicitHeight: 240; visible: root.secondVisible
        color: "#181825"
        Rectangle {
            x: 20; y: 0; width: parent.width - 40; height: 30
            color: root.tick % 3 ? "#313244" : "#585b70"
        }
    }
    IpcHandler {
        target: "probe"
        function showSecond(shown: bool): void { root.secondVisible = shown; }
        function animateUpdates(enabled: bool): void { root.updates = enabled; }
    }
}
