pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/messages"

Item {
    id: scene
    width: 980
    height: 720
    MockMessagingBackend { id: backend; callsEnabled: true }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    MockNotificationBackend { id: noticeBackend }
    QtObject { id: monitor; property string focusedMonitorName: "TEST" }
    QtObject { id: screen; property string name: "TEST"; property int width: 980; property int height: 720 }
    NotificationService { id: notifications; backend: noticeBackend; screens: [screen]; monitorService: monitor }
    QtObject { id: controller; property var route: null; function openConversation(value: var): bool { route = value; return true; } }
    SignalCallNotifications { calls: service.calls; notifications: notifications; messagesController: controller }
    Loader { id: view; anchors.fill: parent; active: false; sourceComponent: MessagesView { hub: hub } }
    TestCase {
        name: "SignalCalls"
        when: windowShown
        function control(name) { return findChild(view.item, name); }
        function received() {
            backend.updateCall({accountId: backend.accountId, conversationId: "chat-a", title: "Alicja", callId: "9223372036854775807",
                state: "RINGING_INCOMING", isOutgoing: false, muted: false, connectedAtMs: 0, errorCode: ""});
        }
        function init() {
            failOnWarning(/.*/);
            scene.width = 980;
            notifications.locked = false; notifications.dnd = false; notifications.clear(); controller.route = null;
            view.active = false;
            backend.seed(); adapter.clear(); service.calls.blocked = false;
            service.calls.refresh();
            view.active = true;
            tryCompare(view, "status", Loader.Ready);
            tryCompare(service.calls, "available", true);
            tryCompare(adapter, "listLoading", false);
            (view.item as MessagesView).focusInitial();
        }
        function cleanup() { backend.release(); view.active = false; notifications.clear(); wait(40); }
        function test_start_scoped_call_and_hide_for_groups() {
            verify(hub.openConversation(adapter.address("chat-a")));
            tryVerify(() => control("startCall").enabled);
            wait(80);
            verify(waitForPolish(scene.Window.window));
            mouseClick(control("startCall"));
            tryCompare(service.calls, "active", true);
            compare(service.calls.current.callId, "-9223372036854775807");
            compare(backend.calls.filter(v => v.method === "call.start").length, 1);
            verify(!control("startCall").enabled);
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.selectedConversation !== null && adapter.selectedConversation.kind === "group");
            verify(!control("startCall").visible);
            verify(control("callBar").visible);
        }
        function test_keyboard_accept_mute_hangup_and_mouse_clears_focus_data() {
            return [{tag: "wide", width: 980}, {tag: "narrow", width: 320}];
        }
        function test_keyboard_accept_mute_hangup_and_mouse_clears_focus(data) {
            scene.width = data.width;
            received();
            tryVerify(() => control("callBar").visible);
            control("conversationList").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_K);
            const accept = control("acceptCall"), end = control("endCall"), mute = control("muteCall");
            verify(accept.activeFocus);
            keyClick(Qt.Key_L); verify(end.activeFocus);
            keyClick(Qt.Key_H); verify(accept.activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(service.calls, "incoming", false);
            tryVerify(() => mute.visible && mute.enabled);
            tryVerify(() => mute.activeFocus);
            keyClick(Qt.Key_Return);
            tryVerify(() => service.calls.current.muted);
            mouseClick(mute);
            tryVerify(() => !service.calls.current.muted);
            verify([Qt.MouseFocusReason, Qt.OtherFocusReason].includes(mute.focusReason));
            mute.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_L); verify(end.activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(service.calls, "active", false);
            keyClick(Qt.Key_Return);
            tryCompare(service.calls, "current", null);
        }
        function test_vim_from_history_to_call_and_details() {
            verify(hub.openConversation(adapter.address("chat-a")));
            tryVerify(() => control("startCall").enabled);
            const history = control("messageHistory"), start = control("startCall"), details = control("conversationDetails");
            tryVerify(() => adapter.draftReady && !adapter.loading);
            waitForRendering(history);
            history.followEnd = false;
            history.forceLayout();
            history.positionViewAtBeginning();
            tryCompare(history, "atYBeginning", true);
            history.focusMessage(0);
            keyClick(Qt.Key_K); verify(control("olderMessages").activeFocus);
            keyClick(Qt.Key_K); verify(start.activeFocus);
            keyClick(Qt.Key_H); verify(details.activeFocus);
            keyClick(Qt.Key_L); verify(start.activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(service.calls, "active", true);
        }
        function test_locked_and_stale_status_never_accept_or_revive() {
            backend.holdResponses = true;
            service.calls.refresh();
            received();
            backend.release();
            tryCompare(service.calls, "incoming", true);
            service.calls.blocked = true;
            verify(!control("acceptCall").enabled);
            verify(!service.calls.accept());
            compare(backend.calls.filter(v => v.method === "call.accept").length, 0);
            backend.serviceState = "reconnecting";
            tryCompare(service.calls, "current", null);
        }
        function test_typing_keeps_hjkl_and_call_survives_window_recreation() {
            hub.openConversation(adapter.address("chat-a"));
            tryVerify(() => adapter.draftReady);
            (view.item as MessagesView).focusInitial(true);
            const editor = control("messageEditor");
            tryVerify(() => editor.activeFocus);
            for (const key of [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L]) keyClick(key);
            compare(editor.text, "hjkl");
            received();
            verify(editor.activeFocus);
            view.active = false; view.active = true;
            tryCompare(view, "status", Loader.Ready);
            verify(control("callBar").visible);
            verify(service.calls.incoming);
        }
        function test_incoming_notice_actions_and_redaction_on_lock_and_end() {
            received();
            tryCompare(notifications, "entries", notifications.entries);
            tryVerify(() => notifications.entries.length === 1);
            const entry = notifications.entries[0];
            compare(entry.summary, "Alicja");
            verify(entry.actions.some(v => v.identifier === "accept"));
            entry.notification.actions.find(v => v.identifier === "accept").invoke();
            tryCompare(service.calls, "incoming", false);
            tryCompare(notifications, "entries", []);
            compare(controller.route.conversationId, "chat-a");
            compare(notifications.history.length, 0);
            backend.updateCall(null); received();
            tryVerify(() => notifications.entries.length === 1);
            notifications.locked = true;
            tryCompare(notifications, "entries", []);
            compare(notifications.history.length, 0);
            notifications.locked = false;
            tryVerify(() => notifications.entries.length === 1);
            backend.updateCall(Object.assign({}, backend.voiceCall, {state: "ENDED"}));
            tryCompare(notifications, "entries", []);
        }
        function test_dnd_keeps_incoming_call_in_hub_without_toast() {
            notifications.dnd = true;
            received();
            compare(notifications.entries.length, 0);
            verify(control("callBar").visible);
            verify(service.calls.incoming);
        }
    }
}
