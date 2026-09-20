import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Quickshell 0.3.1 registers the platform factory at runtime. Its qmltypes
// describe only the uncreatable interface (src/window/panelinterface.hpp).
// Scope this metadata workaround to the factory, never to import/type checks.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var service
    required property var controller
    required property var panels
    required property var battery
    required property var tray
    required property var audio
    property var bluetooth: null
    property var notifications: null
    required property var network
    required property date date
    readonly property bool navigating: screen !== null && controller.screenName === screen.name

    anchors { top: true; left: true; right: true }
    implicitHeight: Metrics.barHeight
    exclusiveZone: Metrics.barHeight
    color: Theme.background
    WlrLayershell.namespace: "putkin-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: navigating ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    BarView {
        id: view
        anchors.fill: parent
        service: root.service
        audio: root.audio
        network: root.network
        bluetooth: root.bluetooth
        notifications: root.notifications
        activeModule: root.panels.screenName === screenName ? root.panels.activeId : ""
        battery: root.battery
        tray: root.tray
        screenName: root.screen ? root.screen.name : ""
        date: root.date
        navigating: root.navigating
        panelActive: root.panels.screenName === screenName && (root.panels.activeId === "quickSettings" || root.panels.activeId === "settings")
        windowedTooltips: true
        batteryPanelActive: root.panels.screenName === screenName && root.panels.activeId === "battery"
        audioPanelActive: root.panels.screenName === screenName && root.panels.activeId === "audio"
        onModuleRequested: (surface, invoker) => root.panels.toggle(surface, root.screen, invoker)
        onAudioRequested: invoker => root.panels.toggle("audio", root.screen, invoker)
        onBatteryRequested: invoker => root.panels.toggle("battery", root.screen, invoker)
        onQuickSettingsRequested: invoker => root.panels.toggle("quickSettings", root.screen, invoker)
        onTrayMenuRequested: (item, invoker) => root.panels.openTray(item, root.screen, invoker)
        onTrayOverflowRequested: invoker => root.panels.toggle("trayOverflow", root.screen, invoker)
        onTrayActivationRequested: (item, secondary) => {
            root.panels.close(false);
            root.controller.close();
            if (secondary) item.secondaryActivate(); else item.activate();
        }
        onDismissed: root.controller.close()
        Keys.onEscapePressed: root.controller.close()
    }
    Connections {
        target: root.controller
        function onEntered(name: string): void {
            if (root.screen && name === root.screen.name)
                view.enter();
        }
        function onResumed(name: string, invoker: var): void {
            if (root.screen && name === root.screen.name) {
                Qt.callLater(() => {
                    if (root.navigating) {
                        if (invoker && invoker.enabled && invoker.visible)
                            invoker.forceActiveFocus(Qt.TabFocusReason);
                        else
                            view.focusQuickSettings();
                    }
                });
            }
        }
    }
}
