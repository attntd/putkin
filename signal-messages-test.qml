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
    property int windowsCreated: 0
    readonly property var testController: controller
    SignalBackend { id: backend; helperArguments: ["--test-scenario", Quickshell.env("PUTKIN_SIGNAL_TEST_SCENARIO")] }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    QtObject { id: monitor; property string focusedMonitorName: "" }
    MessagesController { id: controller; hub: hub; screens: Quickshell.screens; monitorService: monitor; loader: loader }
    LazyLoader {
        id: loader
        MessagesWindow { controller: root.testController; Component.onCompleted: root.windowsCreated++ }
    }
    MessagesIpc { controller: controller }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const focusItems = [];
            function inspect(item) {
                if (item.objectName === "messageEditor" || item.objectName === "conversationList")
                    focusItems.push({name: item.objectName, focus: item.focus, active: item.activeFocus, enabled: item.enabled, visible: item.visible});
                for (const child of item.children) inspect(child);
            }
            if (controller.window) inspect(controller.window.view);
            return JSON.stringify({state: service.state, pid: backend.processId, generation: backend.generation,
                accountId: adapter.accountId, conversations: adapter.conversations.map(v => ({route: v.route, title: v.title})),
                loaded: controller.loaded, windows: root.windowsCreated, interactive: controller.interactive,
                // ListView is a focus scope; Qt may make its current delegate
                // the activeFocusItem while the list itself has activeFocus.
                focus: (focusItems.find(item => item.active) || {}).name || "",
                focusItems: focusItems, focusPending: controller.window ? controller.window.view.composerFocusPending : false,
                selected: adapter.selectedRoute, count: adapter.messages.count, draft: adapter.draftText, draftReady: adapter.draftReady,
                loading: adapter.loading, pending: Object.keys(adapter.requests).length, canSend: adapter.canSend,
                statuses: Array.from({length: adapter.messages.count}, (_, i) => adapter.messages.get(i).status),
                width: controller.window ? controller.window.view.width : 0, height: controller.window ? controller.window.view.height : 0, lastError: adapter.lastError, captured: root.captured});
        }
        function open(): bool { return controller.open(""); }
        function select(index: int): bool { return controller.openConversation(adapter.conversations[index].route); }
        function create(query: string): bool { return adapter.createConversation(query, null); }
        function draft(text: string): void { adapter.editDraft(text); }
        function send(): bool { return adapter.send(); }
        function more(): void { adapter.loadMore(); }
        function receive(wire: string): void { backend.request("test.echo", {receive: JSON.parse(wire)}); }
        function close(): void { controller.close(); }
        function reload(): void { Quickshell.reload(true); }
        function resize(width: int, height: int): void { if (controller.window) { controller.window.view.Window.window.width = width; controller.window.view.Window.window.height = height; } }
        function capture(path: string): bool {
            if (!controller.window) return false;
            root.captured = false;
            return controller.window.view.grabToImage(result => { root.captured = result.saveToFile(path); });
        }
        function quit(): void { Qt.quit(); }
    }
}
