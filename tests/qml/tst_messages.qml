pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../core"
import "../../core/ConversationRoute.js" as Route
import "../../services"
import "../../preview"
import "../../modules/messages"

Item {
    id: scene
    width: 980
    height: 720
    MockMessagingBackend { id: backend }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: messageHub; adapters: [adapter] }
    MockSettingsFile { id: file }
    Settings { id: settings; storage: file }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    Loader { id: view; active: false; anchors.fill: parent; sourceComponent: MessagesView { hub: messageHub } }
    SignalSpy { id: opened; target: messageHub; signalName: "conversationOpened" }
    TestCase {
        name: "Messages"
        when: windowShown
        function control(name) { return findChild(view.item, name); }
        function choose(cid = "chat-a") {
            verify(messageHub.openConversation(adapter.address(cid)));
            tryVerify(() => adapter.selectedRoute !== null && adapter.selectedRoute.conversationId === cid && adapter.draftReady && !adapter.loading);
            wait(80);
        }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            scene.width = 980; scene.height = 720;
            view.active = false;
            backend.seed(); adapter.clear();
            view.active = true;
            tryCompare(view, "status", Loader.Ready);
            tryCompare(adapter, "listLoading", false);
            tryCompare(adapter, "conversations", backend.rows.map(v => Object.assign({}, v, {route: adapter.address(v.conversationId), serviceName: "Signal"})));
            opened.clear();
        }
        function cleanup() { backend.release(); wait(300); view.active = false; settings.cancelEdit(); }
        function test_route_scope_and_stale_replies() {
            verify(!messageHub.openConversation({serviceId: "blueferry", accountId: "account-a", conversationId: "chat-a"}));
            verify(!messageHub.openConversation({serviceId: "signal", accountId: "account-b", conversationId: "chat-a"}));
            verify(!messageHub.openConversation({conversationId: "chat-a"}));
            verify(Route.key({serviceId: "a:b", accountId: "c", conversationId: "d"}) !== Route.key({serviceId: "a", accountId: "b:c", conversationId: "d"}));
            backend.holdResponses = true;
            messageHub.openConversation(adapter.address("chat-a")); messageHub.openConversation(adapter.address("chat-g"));
            backend.release();
            tryVerify(() => adapter.selectedRoute !== null && adapter.selectedRoute.conversationId === "chat-g");
            compare(opened.count, 1);
            verify(backend.calls.every(v => v.params.accountId === "account-a"));
            const count = backend.calls.length;
            backend.event("message.changed", {accountId: "account-b", conversationId: "chat-g", messageId: "group-1"});
            compare(backend.calls.length, count);
        }
        function test_keyboard_send_shift_enter_and_ime_guard() {
            const search = control("conversationSearch");
            search.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Escape); keyClick(Qt.Key_J); keyClick(Qt.Key_K); keyClick(Qt.Key_Return);
            tryVerify(() => adapter.draftReady);
            const editor = control("messageEditor");
            editor.forceActiveFocus(Qt.TabFocusReason);
            for (const c of "hjkl") keyClick(c);
            compare(editor.text, "hjkl");
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            compare(editor.text, "hjkl\n");
            // Actual TextArea handler delegates the Qt composition/preedit state.
            const event = {key: Qt.Key_Return, modifiers: Qt.NoModifier, isAutoRepeat: false, accepted: false};
            // Locate the public composer, independent of ScrollView reparenting.
            let item = editor;
            while (item && !item.handleReturn) item = item.parent;
            verify(item !== null);
            item.handleReturn(event, true);
            compare(event.accepted, false); compare(backend.sentCount, 0);
            keyClick(Qt.Key_Return);
            tryCompare(backend, "sentCount", 1);
            tryCompare(editor, "text", "");
            compare(backend.calls.filter(v => v.method === "message.send").length, 1);
            verify(adapter.messages.get(adapter.messages.count - 1).status !== "Dostarczono");
        }
        function test_draft_pending_switch_and_window_recreation() {
            choose();
            backend.holdResponses = true;
            adapter.editDraft("pierwszy"); adapter.editDraft("najnowszy 🐈");
            messageHub.openConversation(adapter.address("chat-g"));
            backend.release();
            tryVerify(() => backend.storedDrafts["chat-a"].text === "najnowszy 🐈");
            tryVerify(() => adapter.selectedRoute.conversationId === "chat-g");
            adapter.editDraft("grupa");
            wait(300); view.active = false; backend.incoming("chat-a"); view.active = true;
            choose();
            compare(control("messageEditor").text, "najnowszy 🐈");
            // A new adapter session reads the committed draft, as after restart.
            adapter.clear(); choose();
            compare(adapter.draftText, "najnowszy 🐈");
            compare(adapter.messages.count, 50);
        }
        function test_scroll_anchor_pagination_and_incoming() {
            choose();
            const history = control("messageHistory");
            compare(history.count, 50);
            history.followEnd = false;
            history.positionViewAtIndex(8, ListView.Beginning);
            tryVerify(() => history.itemAtIndex(8) !== null && !history.restoring);
            const id = adapter.messages.get(8).messageId;
            const before = history.itemAtIndex(8).y - history.contentY;
            adapter.loadMore();
            tryCompare(history, "count", 100); wait(80);
            compare(adapter.messages.get(58).messageId, id);
            verify(Math.abs(history.itemAtIndex(58).y - history.contentY - before) < 2);
            backend.incoming("chat-a");
            tryCompare(history, "count", 101); wait(80);
            verify(Math.abs(history.itemAtIndex(58).y - history.contentY - before) < 2);
            verify(!history.atYEnd);
            history.positionViewAtEnd(); history.forceLayout(); history.positionViewAtEnd(); wait(30); backend.incoming("chat-a");
            tryCompare(history, "count", 102); wait(80); verify(history.atYEnd, JSON.stringify({y: history.contentY, origin: history.originY, height: history.height, total: history.contentHeight, follow: history.followEnd, restoring: history.restoring}));
        }
        function test_new_conversation_small_layout_disabled_send() {
            scene.width = 320; scene.height = 300;
            control("newConversation").click();
            verify((view.item as MessagesView).creating);
            const recipient = control("newRecipient");
            recipient.text = "lukasz.42";
            control("resolveRecipient").click();
            tryVerify(() => adapter.selectedRoute !== null && adapter.selectedRoute.conversationId === "chat-new" && adapter.draftReady);
            compare(adapter.messages.count, 0);
            verify((view.item as MessagesView).detail); verify(!(view.item as MessagesView).creating);
            verify(control("messageEditor").width > 150);
            adapter.editDraft("nowa");
            verify(adapter.send());
            tryCompare(backend, "sentCount", 1);
            backend.accountState = "relinkRequired";
            verify(!adapter.canSend); verify(!adapter.send());
            control("backToConversations").click();
            verify(!(view.item as MessagesView).detail);
        }
        function test_burst_refresh_queue_and_missing_target() {
            choose();
            backend.holdResponses = true;
            const start = backend.calls.length;
            for (let i = 0; i < 40; i++) backend.incoming("chat-a");
            compare(backend.calls.slice(start).filter(v => v.method === "message.get").length, 1);
            backend.release();
            tryCompare(adapter.messages, "count", 90);
            verify(messageHub.openConversation(adapter.address("missing")));
            compare(adapter.selectedRoute, null);
            tryVerify(() => adapter.lastError !== "");
            compare(adapter.selectedRoute, null);
            compare(adapter.messages.count, 0);
        }
        function test_search_names_numbers_group_authors_and_accents() {
            control("conversationSearch").text = "50101";
            compare(control("conversationList").count, 1);
            choose("chat-g");
            compare(adapter.messages.get(0).author, "Alicja");
            settings.beginEdit();
            waitForRendering(view.item); const original = grabImage(view.item);
            settings.setColor("accent", "#89b4fa"); settings.setColor("accentSecondary", "#f38ba8");
            waitForRendering(view.item); const preview = grabImage(view.item);
            verify(!original.equals(preview));
            settings.cancelEdit(); waitForRendering(view.item); verify(original.equals(grabImage(view.item)));
            settings.beginEdit();
            settings.setColor("accent", "#89b4fa"); settings.setColor("accentSecondary", "#f38ba8");
            verify(settings.save()); tryCompare(settings, "saving", false); settings.cancelEdit();
            waitForRendering(view.item); verify(preview.equals(grabImage(view.item)));
        }
    }
}
