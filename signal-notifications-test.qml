pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "modules/messages"
import "modules/notifications"

ShellRoot {
    id: root
    property bool captured: false
    property var selectedReply: null
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
        id: window
        title: "Syntetyczne powiadomienia S05"
        implicitWidth: 384; implicitHeight: 680
        color: Theme.background
        Controls.ScrollView {
            id: evidenceSurface
            anchors.fill: parent; anchors.margins: 12
            contentWidth: availableWidth
            background: Rectangle { color: Theme.background }
            NotificationCenter { id: center; width: evidenceSurface.availableWidth; service: notifications }
        }
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({state: service.state, pid: backend.processId, generation: backend.generation, accountId: service.accountId,
                notificationsReady: notifications.available, loaded: controller.loaded, selected: adapter.selectedRoute,
                entries: notifications.entries.length, history: notifications.history, pending: !!notices.requestId || Object.keys(notices.pending).length > 0,
                reply: root.selectedReply ? {text: root.selectedReply.text, ready: root.selectedReply.ready, state: root.selectedReply.state,
                    operationId: root.selectedReply.operationId, pending: root.selectedReply.pending, dirty: root.selectedReply.dirty, canSend: root.selectedReply.canSend} : null,
                messages: adapter.messages.count, captured: root.captured});
        }
        function receive(wire: string): void { backend.request("test.echo", {receive: JSON.parse(wire)}); }
        function invoke(index: int, action: string): bool {
            const row = notifications.history[index];
            if (!row || !notifications.invoke(notifications.historyEntry(row.historyKey), action)) return false;
            if (action === "reply") {
                root.selectedReply = notices.session(row.messageReference);
                for (let i = 0; i < center.cards.count; i++) {
                    const card = center.cardAt(i) as NotificationCard;
                    if (card && card.entry.historyKey === row.historyKey) card.focusReply();
                }
            }
            return true;
        }
        function draft(text: string): void { if (root.selectedReply) root.selectedReply.edit(text); }
        function send(): bool { return !!root.selectedReply && root.selectedReply.send(); }
        function expire(): void { notifications.entries.slice().forEach(row => notifications.expire(row)); }
        function closeMessages(): void { controller.close(); }
        function locked(value: bool): void { notifications.locked = value; }
        function dnd(value: bool): void { notifications.dnd = value; }
        function clear(): void { notifications.clearHistory(); }
        function reload(): void { Quickshell.reload(true); }
        function capture(path: string): bool {
            root.captured = false;
            return evidenceSurface.grabToImage(result => { root.captured = result.saveToFile(path); });
        }
        function quit(): void { Qt.quit(); }
    }
}
