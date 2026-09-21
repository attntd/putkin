import QtQml

QtObject {
    id: root
    property bool connected: true
    property bool autoAcknowledge: true
    property string focusedMonitorName: "TEST-1"
    property var monitors: [{ name: "TEST-1", activeId: 9 }, { name: "TEST-2", activeId: 2 }]
    property var workspaces: [
        { id: 1, occupied: true, urgent: false },
        { id: 2, occupied: true, urgent: false },
        { id: 9, occupied: false, urgent: false },
        { id: 12, occupied: true, urgent: true }
    ]
    property var requests: []
    component MockWindow: QtObject {
        property string address
        property var workspace
    }
    readonly property MockWindow firstWindow: MockWindow { address: "0x123"; workspace: ({ id: 12 }) }
    readonly property MockWindow secondWindow: MockWindow { address: "0x456"; workspace: ({ id: 2 }) }
    property var windows: [firstWindow, secondWindow]
    property var activeWindow: firstWindow

    function reset(): void {
        firstWindow.workspace = { id: 12 };
        secondWindow.workspace = { id: 2 };
        windows = [firstWindow, secondWindow];
        activeWindow = firstWindow;
        connected = true;
        autoAcknowledge = true;
        focusedMonitorName = "TEST-1";
        monitors = [{ name: "TEST-1", activeId: 9 }, { name: "TEST-2", activeId: 2 }];
        workspaces = [
            { id: 1, occupied: true, urgent: false },
            { id: 2, occupied: true, urgent: false },
            { id: 9, occupied: false, urgent: false },
            { id: 12, occupied: true, urgent: true }
        ];
        requests = [];
    }

    function many(): void {
        workspaces = Array.from({ length: 30 }, (_, index) => ({
            id: index + 1, occupied: true, urgent: index === 11
        }));
    }

    function focusMonitor(name: string): void {
        requests = requests.concat([{ kind: "focus", monitorName: name }]);
        if (autoAcknowledge)
            focusedMonitorName = name;
    }

    function activateWorkspace(id: int): void {
        requests = requests.concat([{ kind: "activate", workspaceId: id, monitorName: focusedMonitorName }]);
        if (!autoAcknowledge)
            return;
        const previous = monitors.find(item => item.name === focusedMonitorName).activeId;
        monitors = monitors.map(item => ({
            name: item.name,
            activeId: item.name === focusedMonitorName ? id : item.activeId === id ? previous : item.activeId
        }));
    }

    function moveWindow(window: var, id: int): void {
        requests = requests.concat([{ kind: "move", workspaceId: id, address: window.address }]);
        if (autoAcknowledge) window.workspace = { id: id };
    }
    function focusWindow(window: var): void {
        requests = requests.concat([{kind: "focusWindow", address: window.address}]);
        if (autoAcknowledge) {
            activeWindow = window;
            monitors = monitors.map(item => ({name: item.name,
                activeId: item.name === focusedMonitorName ? window.workspace.id : item.activeId}));
        }
    }
    function refreshWindows(): void {}
}
