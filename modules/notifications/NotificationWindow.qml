import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"

// Quickshell 0.3.1 platform factory; same metadata exception as BarWindow.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var service
    required property var controller
    property bool besidePanel: false
    property bool noticesShown: true
    readonly property real panelOffset: besidePanel && screen && screen.width >= Metrics.panelWidth + Metrics.toastWidth + Metrics.panelGap * 3 ? Metrics.panelWidth + Metrics.panelGap : 0
    anchors { top: true; right: true }
    implicitWidth: Math.min(Metrics.toastWidth, screen ? screen.width - Metrics.panelGap * 2 : 1) + Metrics.panelGap + panelOffset
    implicitHeight: stack.implicitHeight + Metrics.barHeight + Metrics.panelGap
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "putkin-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // HyprlandFocusGrab owns focus and dismissal during explicit navigation.
    WlrLayershell.keyboardFocus: stack.navigating ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: stack }
    NotificationStack {
        id: stack
        shown: root.noticesShown
        service: root.service
        controller: root.controller
        screenName: root.screen ? root.screen.name : ""
        y: Metrics.barHeight + Metrics.panelGap
        width: root.width - Metrics.panelGap - root.panelOffset
        height: implicitHeight
        availableHeight: root.screen ? Math.max(1, root.screen.height - Metrics.barHeight - Metrics.panelGap * 2) : 1
    }
    HyprlandFocusGrab {
        windows: [root]
        active: stack.navigating && root.visible
        onCleared: { if (stack.navigating) root.controller.close(); }
    }
}
