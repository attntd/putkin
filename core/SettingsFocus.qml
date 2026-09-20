import QtQml

QtObject {
    id: root
    required property var coordinator
    required property var service
    required property int processId
    property bool pending: false
    readonly property var ownWindow: service.windows.find(item => item.title === "Ustawienia"
        && item.lastIpcObject && item.lastIpcObject.pid === processId) || null
    function focusWindow(): void {
        if (pending && ownWindow && coordinator.activeId === "settings" && service.liveWindow(ownWindow)) {
            pending = false;
            service.backend.focusWindow(ownWindow);
        }
    }
    onOwnWindowChanged: focusWindow()
    readonly property Connections changes: Connections {
        target: root.coordinator
        function onPresented(surface: string): void {
            root.pending = false;
            if (surface !== "settings" || !root.service.windows.some(item => item.title === "Ustawienia")) return;
            root.pending = true;
            root.service.backend.refreshWindows();
            root.focusWindow();
        }
        function onSessionChanged(): void { if (root.coordinator.activeId !== "settings") root.pending = false; }
    }
}
