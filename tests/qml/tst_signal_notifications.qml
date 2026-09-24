pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../components" as UI

Item {
    id: scene
    width: 1366; height: 768
    MockNotificationBackend { id: noticesBackend }
    MockMessagingBackend { id: backend }
    SignalService { id: service; backend: backend }
    NotificationService { id: notifications; backend: noticesBackend; screens: preview.coordinator.screens; monitorService: preview.backend; messaging: messages }
    SignalNotifications { id: messages; service: service; notifications: notifications; messagesController: windowController }
    QtObject {
        id: windowController
        property var route: null
        function openConversation(value: var): bool { route = value; return true; }
    }
    QtObject {
        id: panelLoader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader { active: panelLoader.activeAsync; sourceComponent: preview.panelComponent }
    }
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: panelLoader; notifications: notifications }
    UI.TextField { id: desktop; x: 80; y: 600; width: 200 }
    TestCase {
        name: "SignalNotifications"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.notificationController.close(); preview.coordinator.close(false);
            notifications.clear(); notifications.locked = false; notifications.dnd = false; notifications.defaultTimeout = 5000;
            Object.values(messages.replies).forEach(reply => reply.destroy()); messages.replies = ({}); messages.revision++;
            messages.burstStart = 0; messages.burstCount = 0;
            backend.seed(); messages.reset(); windowController.route = null;
            scene.width = 1366; scene.height = 768;
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            preview.backend.focusedMonitorName = "TEST-1";
            tryCompare(preview, "notificationStack", null);
            panelLoader.itemLoader.asynchronous = false;
            preview.notificationLoader.itemLoader.asynchronous = false;
            desktop.text = ""; desktop.forceActiveFocus(Qt.MouseFocusReason); mouseMove(scene, 40, 600);
        }
        function cleanup() {
            backend.release(); wait(200);
            preview.settings.cancelEdit();
            preview.notificationController.close(); preview.coordinator.close(false);
            notifications.clear(); messages.reset();
            wait(250);
        }
        function incoming(cid = "chat-a") {
            backend.incoming(cid);
            tryVerify(() => notifications.history.some(row => row.messageReference && row.messageReference.conversationId === cid));
            return notifications.history.find(row => row.messageReference.conversationId === cid);
        }
        function card(index = 0) { return preview.notificationStack.cardAt(index); }
        function waitCard() { tryVerify(() => preview.notificationStack !== null && preview.notificationStack.count > 0); wait(240); }
        function reply(index = 0) {
            waitCard(); const value = card(index);
            value.actionAt(1).click();
            tryVerify(() => value.replyEditor !== null && value.replySession.ready);
            tryVerify(() => value.replyEditor.editor.activeFocus);
            return value;
        }
        function test_redaction_removes_exact_history_and_ignores_late_fetch() {
            const first = incoming(); waitCard();
            backend.incoming("chat-a");
            tryVerify(() => notifications.history[0].messageReference.messageId !== first.messageReference.messageId);
            const latest = notifications.history[0].messageReference;
            backend.event("message.redacted", first.messageReference);
            compare(notifications.history.length, 1);
            backend.event("message.redacted", latest);
            compare(notifications.history.length, 0); compare(notifications.entries.length, 0);
            backend.holdResponses = true; backend.incoming("chat-a");
            tryVerify(() => messages.requestId !== "");
            const msg = backend.history["chat-a"][backend.history["chat-a"].length - 1];
            backend.event("message.redacted", {accountId: backend.accountId, conversationId: "chat-a", messageId: msg.messageId});
            backend.release(); wait(400);
            compare(notifications.history.length, 0); compare(notifications.entries.length, 0);
        }
        function test_quick_reply_typing_stops_on_blur_and_lock() {
            backend.configuration = {enabled: true, typingIndicators: true};
            incoming(); const value = reply();
            keyClick(Qt.Key_A); keyClick(Qt.Key_B);
            compare(backend.calls.filter(c => c.method === "typing.set" && c.params.active).length, 1);
            desktop.forceActiveFocus(Qt.TabFocusReason);
            compare(backend.calls.filter(c => c.method === "typing.set" && !c.params.active).length, 1);
            value.replyEditor.editor.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_C);
            notifications.locked = true;
            tryVerify(() => backend.calls.filter(c => c.method === "typing.set" && !c.params.active).length === 2);
        }
        function test_center_and_reply_do_not_read_phone_read_dismisses_exact_card() {
            incoming(); waitCard(); tryCompare(notifications, "unreadCount", 1);
            const older = notifications.history[0].messageReference;
            notifications.centerVisible = true; wait(350); verify(!backend.calls.some(call => call.method === "messages.read"));
            notifications.centerVisible = false;
            backend.incoming("chat-a");
            tryVerify(() => notifications.history[0].messageReference.messageId !== older.messageId);
            const latest = notifications.history[0].messageReference;
            backend.event("message.read", older); wait(100);
            compare(notifications.entries.length, 1);
            verify(messages.invoke(latest, "reply")); wait(100); verify(!backend.calls.some(call => call.method === "messages.read"));
            backend.history["chat-a"].find(v => v.messageId === latest.messageId).unread = false;
            backend.event("message.read", latest);
            tryCompare(notifications, "unreadCount", 0); compare(notifications.entries.length, 0);
            verify(notifications.history[0].body.length > 0);
            verify(!backend.calls.some(call => call.method === "messages.read"));
        }
        function test_read_arriving_during_notification_fetch_cannot_recreate_toast() {
            backend.holdResponses = true; backend.incoming("chat-a");
            tryVerify(() => messages.requestId !== "");
            const latest = backend.history["chat-a"][backend.history["chat-a"].length - 1];
            latest.unread = false;
            backend.event("message.read", {serviceId: "signal", accountId: backend.accountId, conversationId: "chat-a", messageId: latest.messageId});
            backend.release(); wait(500);
            compare(notifications.entries.length, 0); compare(notifications.unreadCount, 0);
        }
        function test_arrival_grouping_no_focus_and_route() {
            const row = incoming(); waitCard();
            verify(desktop.activeFocus); compare(preview.notificationController.screenName, "");
            const original = card();
            backend.incoming("chat-a");
            tryVerify(() => notifications.history[0].messageReference.messageId !== row.messageReference.messageId);
            compare(notifications.entries.length, 1); compare(notifications.history.length, 1); compare(card(), original);
            verify(desktop.activeFocus);
            notifications.notifyError(notifications.entries[0].summary, "Błąd syntetyczny");
            compare(notifications.entries.length, 2); // same title never conflates errors and messages
            card().actionAt(0).click();
            compare(windowController.route, {serviceId: "signal", accountId: "account-a", conversationId: "chat-a"});
            compare(notifications.entries.length, 1); compare(notifications.history.length, 1);
            verify(!backend.calls.some(call => /receipt|read/i.test(call.method)));
        }
        function test_quick_reply_keyboard_context_double_send_and_ime() {
            backend.storedDrafts["chat-a"] = {text: "Szkic pełnego okna", revision: 1};
            incoming(); const value = reply(), editor = value.replyEditor.editor;
            for (const letter of "hjklqd") keyClick(letter);
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            compare(editor.text, "hjklqd\n");
            value.replySession.edit(editor.text + "Zażółć 🐈");
            tryCompare(editor, "text", "hjklqd\nZażółć 🐈");
            const event = {key: Qt.Key_Return, modifiers: Qt.NoModifier, isAutoRepeat: false, accepted: false};
            value.replyEditor.handleReturn(event, true);
            compare(event.accepted, false); compare(backend.sentCount, 0);
            keyClick(Qt.Key_Return);
            findChild(value, "notificationReplySend").click();
            tryCompare(backend, "sentCount", 1);
            tryCompare(editor, "text", "");
            compare(backend.calls.filter(call => call.method === "message.send").length, 1);
            compare(backend.storedDrafts["chat-a"].text, "Szkic pełnego okna");
            compare(windowController.route, null);
        }
        function test_toast_enter_opens_conversation_and_consumes_history() {
            const row = incoming(); waitCard();
            preview.notificationController.focus();
            tryVerify(() => card().selectionControl.activeFocus);
            keyClick(Qt.Key_Return);
            tryVerify(() => windowController.route !== null);
            compare(windowController.route.conversationId, row.messageReference.conversationId);
            compare(notifications.entries.length, 0); compare(notifications.history.length, 0);
            compare(preview.notificationController.screenName, "");
        }
        function test_center_message_buttons_return_to_header_and_delete_data() {
            return [{tag: "mute", bottom: false}, {tag: "reply-action", bottom: true}];
        }
        function test_center_message_buttons_return_to_header_and_delete(data) {
            incoming(); waitCard(); preview.notificationController.openCenter();
            tryCompare(preview.panelHost, "loaded", true);
            tryCompare(preview.panelHost.window, "opacity", 1);
            const item = preview.panelHost.window.page.cardAt(0);
            const mute = findChild(item, "notificationMute");
            keyClick(Qt.Key_J); verify(item.selectionControl.activeFocus);
            keyClick(Qt.Key_L); verify(mute.activeFocus);
            keyClick(Qt.Key_J); verify(item.actionAt(0).activeFocus);
            keyClick(Qt.Key_L); verify(item.actionAt(1).activeFocus);
            keyClick(Qt.Key_K); verify(mute.activeFocus);
            keyClick(Qt.Key_H); verify(item.selectionControl.activeFocus);
            keyClick(Qt.Key_L);
            if (data.bottom) { keyClick(Qt.Key_J); keyClick(Qt.Key_L); }
            keyClick(Qt.Key_D);
            compare(notifications.entries.length, 0); compare(notifications.history.length, 0);
            compare(windowController.route, null);
            verify(!backend.calls.some(call => call.method === "message.send" || call.method === "messages.read"));
        }
        function test_action_navigation_after_conversation_refresh_data() {
            return [
                {tag: "toast-mute", center: false, close: false},
                {tag: "toast-close", center: false, close: true},
                {tag: "center-mute", center: true, close: false},
                {tag: "center-close", center: true, close: true},
                {tag: "async-toast-mute", center: false, close: false, async: true},
                {tag: "async-toast-close", center: false, close: true, async: true},
                {tag: "async-center-mute", center: true, close: false, async: true},
                {tag: "async-center-close", center: true, close: true, async: true},
                {tag: "expired-center", center: true, close: false, expired: true, async: true}
            ];
        }
        function test_action_navigation_after_conversation_refresh(data) {
            panelLoader.itemLoader.asynchronous = !!data.async;
            preview.notificationLoader.itemLoader.asynchronous = !!data.async;
            incoming(); waitCard();
            if (data.expired) {
                notifications.expire(notifications.entries[0]);
                tryCompare(preview, "notificationStack", null);
            }
            let item;
            if (data.center) {
                preview.notificationController.openCenter();
                tryCompare(preview.panelHost, "loaded", true);
                tryCompare(preview.panelHost.window, "opacity", 1);
                item = preview.panelHost.window.page.cardAt(0);
                keyClick(Qt.Key_J);
            } else {
                preview.notificationController.focus();
                item = card();
            }
            tryVerify(() => item.selectionControl.activeFocus);
            const mute = findChild(item, "notificationMute");
            keyClick(Qt.Key_L); verify(mute.activeFocus);
            if (data.close) { keyClick(Qt.Key_L); verify(item.closeControl.activeFocus); }
            const header = data.close ? item.closeControl : mute;
            keyClick(Qt.Key_J); verify(item.actionAt(0).activeFocus, "j reaches Open before Signal refresh");
            keyClick(Qt.Key_L); verify(item.actionAt(1).activeFocus);
            keyClick(Qt.Key_K); verify(header.activeFocus);
            backend.rows[0].title = "Odświeżona rozmowa";
            backend.event("conversation.changed", {accountId: "account-a", conversationId: "chat-a"});
            tryVerify(() => item.presentation.summary === "Odświeżona rozmowa");
            wait(200);
            verify(header.activeFocus);
            keyClick(Qt.Key_J); verify(item.actionAt(0).activeFocus, "j reaches Open after Signal refresh");
            keyClick(Qt.Key_L); verify(item.actionAt(1).activeFocus);
            keyClick(Qt.Key_K); verify(header.activeFocus);
            keyClick(Qt.Key_D);
            compare(notifications.history.length, 0);
            compare(notifications.entries.length, 0);
        }
        function test_replacement_during_edit_timeout_other_conversation_and_hotplug() {
            notifications.defaultTimeout = 300;
            incoming(); const value = reply(), session = value.replySession;
            session.edit("Stały odbiorca");
            backend.incoming("chat-a"); backend.incoming("chat-g");
            wait(600);
            compare(session.text, "Stały odbiorca"); compare(session.route.conversationId, "chat-a");
            verify(notifications.hasMessageToast(session.route));
            verify(value.replyEditor.editor.activeFocus);
            preview.coordinator.screens = [preview.secondScreen];
            compare(notifications.entries[0].monitorName, "TEST-2");
            verify(session.text === "Stały odbiorca");
            compare(backend.sentCount, 0);
        }
        function test_center_expired_actions_reply_and_receipt_separation() {
            const row = incoming(); waitCard();
            notifications.expire(notifications.entries[0]);
            tryCompare(preview, "notificationStack", null);
            compare(notifications.history[0].actions.length, 0); // descriptor survives; closures do not
            preview.notificationController.openCenter();
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => findChild(preview, "notificationAction-1") !== null);
            const action = findChild(preview, "notificationAction-1"); action.click();
            tryVerify(() => findChild(preview, "notificationReplyEditor") !== null);
            const editor = findChild(preview, "notificationReplyEditor");
            tryVerify(() => editor.activeFocus);
            tryVerify(() => !editor.readOnly);
            compare(preview.coordinator.activeId, "notifications");
            keyClick(Qt.Key_H); keyClick(Qt.Key_Return);
            tryCompare(backend, "sentCount", 1);
            compare(notifications.unreadCount, 0);
            notifications.clearHistory();
            verify(!backend.calls.some(call => /receipt|read/i.test(call.method)));
            compare(backend.sentCount, 1);
            verify(!notifications.invoke(row, "open"));
        }
        function test_dnd_mute_lock_disconnect_and_redaction() {
            notifications.dnd = true; const row = incoming();
            compare(notifications.entries.length, 0); verify(messages.canOpen(row.messageReference));
            notifications.dnd = false; compare(notifications.entries.length, 0);
            verify(notifications.invoke(row, "mute"));
            tryVerify(() => messages.records[JSON.stringify(["signal", "account-a", "chat-a"])].muted);
            backend.incoming("chat-a"); wait(350); compare(notifications.entries.length, 0);
            notifications.locked = true;
            compare(notifications.history[0].body, "Nowa wiadomość");
            compare(notifications.messageActions(row.messageReference).length, 0);
            verify(!notifications.invoke(row, "reply")); verify(!notifications.invoke(row, "open"));
            backend.incoming("chat-g"); wait(350);
            verify(notifications.history.every(value => value.body === "Nowa wiadomość"));
            notifications.locked = false;
            tryVerify(() => notifications.history.every(value => value.body !== "Nowa wiadomość"));
            compare(notifications.entries.length, 0);
            backend.accountState = "relinkRequired";
            compare(notifications.messageActions(row.messageReference).length, 0);
            verify(!notifications.invoke(row, "open"));
        }
        function test_failed_unknown_restart_and_late_confirmation() {
            backend.replyResult = "unknown";
            incoming(); const value = reply(), session = value.replySession;
            session.edit("Zachowana treść"); verify(session.send());
            tryCompare(session, "state", "unknown"); tryCompare(session, "pending", "");
            compare(session.text, "Zachowana treść"); verify(!session.canSend); verify(!session.canRetry); verify(!session.send());
            backend.generation += "reload";
            tryVerify(() => session.ready && session.state === "unknown");
            compare(backend.sentCount, 1); compare(session.text, "Zachowana treść");
            backend.settleReply("chat-a", "sent", false);
            tryCompare(session, "text", ""); compare(backend.sentCount, 1);
            backend.replyResult = "failed";
            session.edit("Jawne ponowienie"); verify(session.send());
            tryCompare(session, "canRetry", true); compare(session.text, "Jawne ponowienie");
            const op = session.operationId; verify(session.retry());
            tryCompare(session, "state", "sent"); compare(session.operationId, op); compare(backend.sentCount, 2);
        }
        function test_deleted_missing_phone_and_burst() {
            const row = incoming(); waitCard();
            notifications.expire(notifications.entries[0]);
            const message = backend.history["chat-a"].find(value => value.messageId === row.messageReference.messageId);
            message.kind = "deleted"; message.text = null;
            backend.event("message.changed", {accountId: "account-a", conversationId: "chat-a", messageId: message.messageId});
            tryCompare(notifications, "history", []);
            compare(notifications.entries.length, 0);
            message.origin = "phone"; message.direction = "outgoing";
            backend.event("message.received", {accountId: "account-a", conversationId: "chat-a", messageId: message.messageId});
            wait(250); compare(notifications.entries.length, 0);
            backend.rows = backend.rows.filter(value => value.conversationId !== "chat-a");
            message.origin = "remote"; message.direction = "incoming";
            backend.event("conversation.changed", {accountId: "account-a", conversationId: "chat-a"});
            tryVerify(() => !messages.canOpen(row.messageReference));
            for (let i = 0; i < 20; ++i) {
                const cid = "burst-" + i;
                backend.rows.push({conversationId: cid, title: "Nadrabianie " + i, canSend: true, muted: false});
                backend.history[cid] = []; backend.incoming(cid);
            }
            tryVerify(() => notifications.history.length === 20);
            verify(notifications.entries.length <= 3);
            compare(Object.keys(messages.pending).length, 0);
        }
        function test_accent_preview_cancel_and_small_card() {
            incoming(); const value = reply();
            scene.width = 320; scene.height = 300;
            wait(100); verify(value.width <= 320); verify(value.height <= 268);
            const before = Theme.accent;
            preview.settings.beginEdit(); preview.settings.setColor("accent", "#f38ba8"); preview.settings.setColor("accentSecondary", "#a6e3a1");
            compare(Theme.accent, "#f38ba8");
            compare(value.replyEditor.editor.color, Theme.text);
            preview.settings.cancelEdit(); compare(Theme.accent, before);
            preview.settings.beginEdit(); preview.settings.setColor("accent", "#f9e2af"); preview.settings.setColor("accentSecondary", "#89dceb");
            verify(preview.settings.save()); tryCompare(preview.settings, "saving", false);
            compare(Theme.accent, "#f9e2af"); compare(Theme.accentSecondary, "#89dceb");
            preview.settings.beginEdit(); preview.settings.resetDraft(); verify(preview.settings.save()); tryCompare(preview.settings, "saving", false);
        }
    }
}
