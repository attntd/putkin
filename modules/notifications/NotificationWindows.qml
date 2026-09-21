pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../core"

Variants {
    id: root
    required property var service
    required property var controller
    required property var panels
    model: service.screens
    delegate: QtObject {
        id: monitor
        required property ShellScreen modelData
        readonly property bool panelOpen: modelData !== null && root.panels.screenName === modelData.name
        property bool noticesShown: false
        function sync(): void {
            if (!modelData) { release.stop(); loader.activeAsync = false; noticesShown = false; return; }
            const notices = root.service.visibleOn(modelData.name);
            const show = notices.length > 0 && (!panelOpen || root.panels.activeId !== "notifications" && notices.some(entry => entry.notification && entry.notification.internal === true && !entry.messageReference));
            noticesShown = show;
            if (show) { release.stop(); loader.activeAsync = true; }
            else release.restart();
        }
        readonly property Timer release: Timer { interval: Metrics.panelFade; onTriggered: loader.activeAsync = false }
        readonly property LazyLoader loader: LazyLoader {
            id: loader
            NotificationWindow { screen: monitor.modelData; service: root.service; controller: root.controller; besidePanel: monitor.panelOpen && root.panels.activeId !== "launcher"; noticesShown: monitor.noticesShown }
        }
        readonly property Connections changes: Connections { target: root.service; function onChanged(): void { monitor.sync(); } }
        readonly property Connections panels: Connections { target: root.panels; function onSessionChanged(): void { monitor.sync(); } }
        Component.onCompleted: sync()
    }
}
