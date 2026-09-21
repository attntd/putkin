import QtQuick

QtObject {
    id: root
    required property var workspaceService
    property var applications: []
    property var pendingApplication: null
    readonly property var matchingWindows: pendingApplication && workspaceService.available
        ? workspaceService.windows.filter(window => matches(pendingApplication, window)) : []

    function normalized(value: string): string { return value.toLowerCase().replace(/\.desktop$/, ""); }
    function find(id: string): var {
        return applications.find(app => normalized(app.id) === normalized(id)) || null;
    }
    function identify(notification: var): string {
        if (notification.internal === true) return "";
        const declared = notification.desktopEntry || (notification.hints && notification.hints["desktop-entry"]) || "";
        const app = declared ? find(declared) : null;
        if (app) return app.id;
        // Some clients, including Electron, omit desktop-entry. Accept only an
        // unambiguous exact name from the installed application catalog.
        const named = applications.filter(item => item.name.toLowerCase() === notification.appName.toLowerCase());
        return named.length === 1 ? named[0].id : "";
    }
    function matches(app: var, window: var): bool {
        if (!workspaceService.liveWindow(window) || !window.lastIpcObject) return false;
        const classes = [app.id, app.startupClass || ""].filter(value => value).map(normalized);
        const metadata = window.lastIpcObject;
        return [metadata.class || "", metadata.initialClass || ""].some(value => value && classes.indexOf(normalized(value)) >= 0);
    }
    function focusPending(): bool {
        if (!pendingApplication || !matchingWindows.length) return false;
        const window = matchingWindows.find(item => item === workspaceService.activeWindow) || matchingWindows[0];
        pendingApplication = null;
        deadline.stop();
        workspaceService.backend.focusWindow(window);
        return true;
    }
    function openPending(): void {
        if (!pendingApplication) return;
        workspaceService.backend.refreshWindows();
        if (!focusPending() && pendingApplication) pendingApplication.execute();
    }
    function activate(id: string): bool {
        const app = find(id);
        if (!app) return false;
        if (pendingApplication === app) return true;
        pendingApplication = app;
        deadline.restart();
        // Let the notification panel release its focus before showing the app.
        Qt.callLater(openPending);
        return true;
    }
    onMatchingWindowsChanged: Qt.callLater(focusPending)
    readonly property Timer deadline: Timer { interval: 5000; onTriggered: root.pendingApplication = null }
}
