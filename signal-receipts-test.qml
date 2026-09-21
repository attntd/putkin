pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "modules/messages"

ShellRoot {
    id: root
    property bool captured: false
    readonly property var testController: controller
    SignalBackend { id: backend; helperArguments: ["--test-scenario", Quickshell.env("PUTKIN_SIGNAL_TEST_SCENARIO")] }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    QtObject { id: monitor; property string focusedMonitorName: "" }
    MessagesController { id: controller; hub: hub; screens: Quickshell.screens; monitorService: monitor; loader: loader; blocked: notifications.locked }
    LazyLoader { id: loader; MessagesWindow { controller: root.testController } }
    NotificationBackend { id: noticesBackend }
    NotificationService { id: notifications; backend: noticesBackend; screens: Quickshell.screens; monitorService: monitor; messaging: notices }
    SignalNotifications { id: notices; service: service; notifications: notifications; messagesController: controller }
    FloatingWindow {
        id: cover
        title: "Syntetyczne inne okno S06"
        implicitWidth: 300; implicitHeight: 180
        color: Theme.background
        Item { id: coverItem; anchors.fill: parent }
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const view = controller.window ? controller.window.view : null;
            return JSON.stringify({state: service.state, pid: backend.processId, generation: backend.generation, accountId: service.accountId,
                loaded: controller.loaded, interactive: controller.interactive, selected: adapter.selectedRoute,
                unread: hub.unreadCount, entries: notifications.entries.length, history: notifications.history,
                pending: !!notices.requestId || Object.keys(notices.pending).length > 0 || Object.keys(adapter.requests).length > 0,
                reading: view ? view.readingEnabled : false, active: view ? view.Window.active : false,
                minimized: controller.window ? controller.window.minimized : false, locked: notifications.locked,
                visibleUnread: view ? view.historyView.visibleUnread() : [],
                viewport: view ? {y: view.historyView.contentY, height: view.historyView.height,
                    width: view.historyView.width, restoring: view.historyView.restoring,
                    followEnd: view.historyView.followEnd, opacity: view.parent.opacity} : null,
                count: adapter.messages.count, statuses: Array.from({length: adapter.messages.count}, (_, i) => adapter.messages.get(i).status),
                lastError: adapter.lastError, captured: root.captured});
        }
        function receive(wire: string): void { backend.request("test.echo", {receive: JSON.parse(wire)}); }
        function select(index: int): bool { return controller.openConversation(adapter.conversations[index].route); }
        function activate(): void { if (controller.window) controller.window.view.Window.window.requestActivate(); }
        function coverMessages(): void { coverItem.Window.window.requestActivate(); }
        function minimize(value: bool): void { if (controller.window) controller.window.minimized = value; }
        function scroll(index: int): void { if (controller.window) controller.window.view.historyView.positionViewAtIndex(index, ListView.Beginning); }
        function close(): void { controller.close(); }
        function center(value: bool): void { notifications.centerVisible = value; }
        function locked(value: bool): void { notifications.locked = value; }
        function draft(text: string): void { adapter.editDraft(text); }
        function send(): bool { return adapter.send(); }
        function reload(): void { Quickshell.reload(true); }
        function capture(path: string): bool {
            root.captured = false;
            return !!controller.window && controller.window.view.grabToImage(result => { root.captured = result.saveToFile(path); });
        }
        function quit(): void { Qt.quit(); }
    }
}
