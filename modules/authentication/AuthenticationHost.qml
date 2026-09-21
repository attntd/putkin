pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

Scope {
    id: root
    required property var service
    required property var screens
    required property var monitorService
    required property var panels
    required property var barFocus
    property var screen: null
    property string selectedScreenName: ""
    Connections {
        target: root.service
        function onOpened(): void {
            root.panels.close(false); root.barFocus.close();
            root.screen = root.screens.find(item => item.name === root.monitorService.focusedMonitorName) || root.screens[0] || null;
            root.selectedScreenName = root.screen ? root.screen.name : "";
            if (!root.screen) root.service.cancelAll();
        }
    }
    onScreensChanged: {
        if (service.active && !screens.some(item => item.name === selectedScreenName)) service.cancelAll();
    }
    LazyLoader {
        active: root.service.current !== null && root.screen !== null
        // Quickshell's runtime window factory is not represented in qmltypes.
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            id: window
            screen: root.screen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "putkin-authentication"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.service.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region { item: view; width: root.service.active ? view.width : 0; height: root.service.active ? view.height : 0 }
            AuthenticationView {
                id: view
                request: root.service.current
                interactive: root.service.active
                anchors.centerIn: parent
                width: Math.max(1, Math.min(420, parent.width - 2 * Metrics.space16))
                height: Math.min(implicitHeight, parent.height - 2 * Metrics.space16)
            }
            onClosed: { if (root.service.active) root.service.cancelAll(); }
        }
    }
}
