import QtQuick
import "ConversationRoute.js" as Route

QtObject {
    id: root
    required property var hub
    required property var screens
    required property var monitorService
    required property var loader
    property var panels: null
    property var barFocus: null
    property bool blocked: false
    property bool interactive: false
    property var screen: null
    property string lastError: ""
    readonly property bool loaded: loader.active
    readonly property var window: loaded ? loader.item : null
    signal presented()
    function open(monitor: string): bool {
        if (blocked) return false;
        const target = screens.find(item => item.name === (monitor || monitorService.focusedMonitorName)) || screens[0];
        if (!target) return false;
        if (panels) panels.close(false);
        if (barFocus) barFocus.close();
        release.stop();
        if (!loaded) screen = target;
        interactive = true;
        loader.activeAsync = true;
        if (window) window.minimized = false;
        presented();
        return true;
    }
    function openConversation(route: var, monitor = ""): bool {
        if (blocked || !Route.valid(route) || !hub.adapterFor(route) || !screens.length) return false;
        if (!hub.openConversation(route)) return false;
        return open(monitor);
    }
    function close(): void {
        for (const adapter of hub.adapters) adapter.flushDraft();
        interactive = false;
        release.restart();
    }
    onBlockedChanged: { if (blocked) close(); }
    onScreensChanged: {
        if (screen && screens.indexOf(screen) < 0) {
            screen = screens.find(item => item.name === monitorService.focusedMonitorName) || screens[0] || null;
            if (!screen) close();
        }
    }
    readonly property Timer release: Timer {
        interval: Metrics.panelFade + 32
        onTriggered: { if (!root.interactive) { root.loader.activeAsync = false; root.screen = null; } }
    }
}
