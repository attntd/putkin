import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Same platform-factory metadata workaround as BarWindow, Quickshell 0.3.1.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var service
    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.background
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "putkin-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    WallpaperView {
        anchors.fill: parent
        service: root.service
        pixelScale: root.screen ? root.screen.devicePixelRatio : 1
    }
}
