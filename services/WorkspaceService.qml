import QtQuick

// The backend owns the connection; this model owns numbering and action sequencing.
QtObject {
    id: root

    required property var backend
    readonly property bool available: backend.connected && backend.monitors.length > 0
    readonly property var monitors: available ? backend.monitors : []
    readonly property string focusedMonitorName: available ? backend.focusedMonitorName : ""
    readonly property var activeWindow: available ? backend.activeWindow : null
    readonly property var windows: available ? backend.windows : []
    readonly property ListModel workspaces: ListModel {}
    readonly property var snapshot: makeSnapshot()
    property string lastError: ""
    property int pendingId: -1
    property string pendingMonitor: ""
    property bool activationSent: false
    property int commandRequest: -1
    property var pendingWindow: null
    property bool movingWindow: false
    readonly property bool busy: pendingId > 0
    property int actionTimeout: 2000

    signal updated()
    signal commandFinished(int request, string error)

    function liveWindow(window: var): bool {
        return available && window !== null && windows.indexOf(window) >= 0
            && /^(?:0x)?[0-9a-fA-F]{1,16}$/.test(window.address)
            && !/^(?:0x)?0+$/.test(window.address);
    }

    function executeCommand(request: int, action: string, id: real, window: var, monitor: string): bool {
        if (!available || !monitorAvailable(monitor)) { lastError = qsTr("Hyprland niedostępny"); return false; }
        if (busy) { lastError = qsTr("Trwa zmiana workspace"); return false; }
        if (!Number.isInteger(id) || id < 1 || id > 10 || (action !== "switch" && action !== "move")) return false;
        if (action === "move" && !liveWindow(window)) { lastError = qsTr("Okno sprzed otwarcia launchera jest niedostępne"); return false; }
        commandRequest = request;
        movingWindow = action === "move";
        pendingWindow = action === "move" ? window : null;
        startAction(id, monitor);
        return true;
    }

    function monitorAvailable(name: string): bool {
        return monitors.some(monitor => monitor.name === name);
    }

    function activeId(name: string): int {
        const monitor = monitors.find(item => item.name === name);
        return monitor ? monitor.activeId : -1;
    }

    function indexOf(id: int): int {
        for (let i = 0; i < workspaces.count; ++i) {
            if (workspaces.get(i).workspaceId === id)
                return i;
        }
        return -1;
    }

    function makeSnapshot(): var {
        const entries = {};
        for (let id = 1; id <= 5; ++id)
            entries[id] = { workspaceId: id, occupied: false, urgent: false, visibleOn: "" };
        if (available) {
            for (const item of backend.workspaces) {
                if (item.id > 0 && (item.occupied || item.urgent || entries[item.id]))
                    entries[item.id] = { workspaceId: item.id, occupied: item.occupied, urgent: item.urgent, visibleOn: "" };
            }
            for (const monitor of monitors) {
                if (monitor.activeId <= 0)
                    continue;
                if (!entries[monitor.activeId])
                    entries[monitor.activeId] = { workspaceId: monitor.activeId, occupied: false, urgent: false, visibleOn: "" };
                entries[monitor.activeId].visibleOn = monitor.name;
            }
        }
        return Object.values(entries).sort((a, b) => a.workspaceId - b.workspaceId);
    }

    function syncModel(): void {
        // Retain delegates and their focus when only occupancy/urgency changes.
        for (let i = 0; i < snapshot.length; ++i) {
            const entry = snapshot[i];
            while (i < workspaces.count && workspaces.get(i).workspaceId < entry.workspaceId)
                workspaces.remove(i);
            if (i >= workspaces.count || workspaces.get(i).workspaceId !== entry.workspaceId)
                workspaces.insert(i, entry);
            else {
                for (const role of ["occupied", "urgent", "visibleOn"])
                    workspaces.setProperty(i, role, entry[role]);
            }
        }
        if (workspaces.count > snapshot.length)
            workspaces.remove(snapshot.length, workspaces.count - snapshot.length);
        advanceAction();
        updated();
    }

    function cancelAction(message: string): void {
        const request = commandRequest;
        commandRequest = -1;
        deadline.stop();
        pendingId = -1;
        pendingMonitor = "";
        pendingWindow = null;
        movingWindow = false;
        activationSent = false;
        lastError = message;
        if (request >= 0) commandFinished(request, message);
    }

    function activate(id: int, monitorName: string): bool {
        if (!available || !monitorAvailable(monitorName)) {
            lastError = qsTr("Hyprland niedostępny");
            return false;
        }
        if (indexOf(id) < 0 || busy)
            return false;
        startAction(id, monitorName);
        return true;
    }

    function startAction(id: int, monitorName: string): void {
        lastError = "";
        pendingMonitor = monitorName;
        pendingId = id;
        activationSent = false;
        deadline.restart();
        if (!movingWindow && focusedMonitorName !== monitorName)
            backend.focusMonitor(monitorName);
        advanceAction();
    }

    function advanceAction(): void {
        if (!busy)
            return;
        if (!monitorAvailable(pendingMonitor)) {
            cancelAction(qsTr("Monitor lub Hyprland niedostępny"));
            return;
        }
        if (movingWindow) {
            if (!liveWindow(pendingWindow)) { cancelAction(qsTr("Przenoszone okno zostało zamknięte")); return; }
            if (pendingWindow.workspace && pendingWindow.workspace.id === pendingId) { cancelAction(""); return; }
            if (!activationSent) {
                activationSent = true;
                backend.moveWindow(pendingWindow, pendingId);
            }
            return;
        }
        if (activeId(pendingMonitor) === pendingId && focusedMonitorName === pendingMonitor) {
            cancelAction("");
            return;
        }
        if (!activationSent && focusedMonitorName === pendingMonitor) {
            activationSent = true;
            backend.activateWorkspace(pendingId);
        }
    }

    onSnapshotChanged: syncModel()
    onFocusedMonitorNameChanged: advanceAction()
    onMonitorsChanged: advanceAction()
    onWindowsChanged: advanceAction()
    Component.onCompleted: syncModel()

    readonly property Timer deadline: Timer {
        interval: root.actionTimeout
        onTriggered: root.cancelAction(qsTr("Hyprland nie potwierdził zmiany workspace"))
    }
    readonly property Connections windowChanges: Connections {
        target: root.pendingWindow
        function onWorkspaceChanged(): void { root.advanceAction(); }
    }
}
