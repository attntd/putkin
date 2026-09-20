import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Quickshell 0.3.1 runtime factory; see BarWindow's metadata workaround.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var host
    screen: host.screen
    visible: host.loaded
    anchors.bottom: true
    implicitWidth: Math.min(Metrics.osdWidth, screen ? screen.width - Metrics.space24 : Metrics.osdWidth)
    implicitHeight: Metrics.osdHeight + Metrics.space24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "putkin-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    LevelOsd {
        width: parent.width; height: Metrics.osdHeight
        shown: root.host.service.visible
        level: root.host.service.level
        label: root.host.service.label
        symbol: root.host.service.symbol
        fillColor: root.host.service.fillColor
    }
}
