pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../core"
import "../../core/Actions.js" as Actions
import "../../services"
import "../../preview"
import "../../modules/bar"

Item {
    id: scene
    width: 1024
    height: 100
    property var screens: [{name: "LEFT", width: 1200, height: 800}, {name: "RIGHT", width: 800, height: 600}]
    MockMessagingBackend { id: backend }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    QtObject {
        id: loader
        property bool activeAsync: false
        readonly property bool active: activeAsync
        property var item: ({minimized: false})
    }
    QtObject {
        id: monitor
        property string focusedMonitorName: "RIGHT"
        property var windows: []
        property var focused: null
        property int refreshes: 0
        readonly property QtObject backend: QtObject {
            function focusWindow(window: var): void { monitor.focused = window; }
            function refreshWindows(): void { monitor.refreshes++; }
        }
        function liveWindow(window: var): bool { return windows.indexOf(window) >= 0; }
    }
    MessagesController { id: controller; hub: hub; screens: scene.screens; monitorService: monitor; loader: loader }
    MessagesFocus { controller: controller; service: monitor; processId: 42 }
    ActionController {
        id: actions
        messages: controller
        coordinator: null; launcher: null; hyprland: null; windowActions: null
        barFocus: null; notificationFocus: null; notifications: null
        audio: null; brightness: null; sessionService: null
    }
    MockHyprland { id: workspaceBackend }
    WorkspaceService { id: workspaces; backend: workspaceBackend }
    BarView {
        id: bar
        width: scene.width; height: Metrics.barHeight
        service: workspaces; screenName: "LEFT"; date: new Date(2026, 8, 20)
        messages: controller
        onMessagesRequested: controller.open(screenName)
    }
    TestCase {
        name: "MessagesController"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            backend.seed(); adapter.clear();
            controller.blocked = false; controller.close();
            tryCompare(loader, "active", false);
            scene.screens = [{name: "LEFT", width: 1200, height: 800}, {name: "RIGHT", width: 800, height: 600}];
            monitor.windows = []; monitor.focused = null; monitor.focusedMonitorName = "RIGHT";
        }
        function test_lazy_monitor_focus_same_window_hotplug_and_lock() {
            verify(!controller.loaded);
            verify(controller.open("")); compare(controller.screen.name, "RIGHT");
            const foreign = {title: "Wiadomości", lastIpcObject: {pid: 99}};
            monitor.windows = [foreign]; compare(monitor.focused, null);
            const own = {title: "Wiadomości", lastIpcObject: {pid: 42}};
            monitor.windows = [foreign, own]; compare(monitor.focused, own);
            verify(controller.open("LEFT")); compare(controller.screen.name, "RIGHT"); // Existing window keeps its monitor.
            const item = controller.window;
            verify(controller.openConversation(adapter.address("chat-a")));
            tryVerify(() => adapter.selectedRoute !== null);
            compare(controller.window, item);
            controller.close(); verify(!controller.interactive); verify(controller.loaded);
            // Reopening during fade cancels destruction.
            verify(controller.open("RIGHT")); wait(300); verify(controller.loaded); compare(controller.window, item);
            scene.screens = [scene.screens[0]]; compare(controller.screen.name, "LEFT");
            controller.blocked = true; verify(!controller.open("")); verify(!controller.openConversation(adapter.address("chat-a")));
            tryCompare(controller, "loaded", false);
        }
        function test_action_and_full_address_reject_foreign_account() {
            verify(!controller.openConversation({serviceId: "signal", accountId: "wrong", conversationId: "chat-a"}));
            verify(!controller.loaded);
            verify(actions.invoke("messages", null, "LEFT"));
            tryCompare(controller, "loaded", true); compare(controller.screen.name, "LEFT");
        }
        function test_bar_entry_keyboard_and_model_unread() {
            tryVerify(() => hub.unreadCount === 181);
            const button = findChild(bar, "barMessages");
            verify(button.visible); compare(button.symbol, "chat"); compare(button.foreground, Theme.text);
            button.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_L); verify(bar.quickSettingsButton.activeFocus);
            keyClick(Qt.Key_H); verify(button.activeFocus);
            keyClick(Qt.Key_Return);
            verify(controller.loaded); compare(controller.screen.name, "LEFT");
            compare(hub.unreadCount, 181);
        }
        function test_old_keyboard_catalog_upgrade_preserves_user_commands() {
            const rows = Actions.defaults().filter(v => v.action !== "messages");
            rows.find(v => v.action === "settings").command = ":messages";
            const parsed = Actions.parse(JSON.stringify({schemaVersion: 1, bindings: rows}));
            verify(!parsed.error);
            compare(parsed.value.find(v => v.action === "settings").command, ":messages");
            compare(parsed.value.find(v => v.action === "messages").command, "");
            compare(parsed.value.find(v => v.action === "messages").shortcut, "");
            rows.pop(); verify(Actions.parse(JSON.stringify({schemaVersion: 1, bindings: rows})).error);
        }
    }
}
