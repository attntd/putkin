import QtQml

QtObject {
    id: root
    required property var controller
    required property var service
    required property int processId
    property bool pending: false
    readonly property var ownWindow: service.windows.find(item => item.title === "Wiadomości"
        && item.lastIpcObject && item.lastIpcObject.pid === processId) || null
    function activate(): void {
        if (pending && ownWindow && controller.interactive && service.liveWindow(ownWindow)) {
            pending = false;
            service.backend.focusWindow(ownWindow);
        }
    }
    onOwnWindowChanged: activate()
    readonly property Connections events: Connections {
        target: root.controller
        function onPresented(): void {
            root.pending = true;
            root.service.backend.refreshWindows();
            root.activate();
        }
        function onInteractiveChanged(): void { if (!root.controller.interactive) root.pending = false; }
    }
}
