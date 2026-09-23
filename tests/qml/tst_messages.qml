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
            (view.item as MessagesView).focusInitial();
        }
        function cleanup() { backend.release(); wait(300); view.active = false; settings.cancelEdit(); wait(100); }
        function test_initial_list_and_conversation_navigation_data() {
            return [{tag: "wide", width: 980}, {tag: "narrow", width: 320}];
        }
        function test_initial_list_and_conversation_navigation(data) {
            scene.width = data.width;
            const list = control("conversationList");
            verify(list.activeFocus);
            compare(list.currentIndex, 0);
            for (const key of [Qt.Key_Down, Qt.Key_K, Qt.Key_J, Qt.Key_Up]) keyClick(key);
            compare(list.currentIndex, 0);
            compare(adapter.selectedRoute, null);
            for (const key of [Qt.Key_L, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Right]) {
                keyClick(Qt.Key_Down);
                const route = (view.item as MessagesView).filtered[list.currentIndex].route;
                keyClick(key, key === Qt.Key_Enter ? Qt.KeypadModifier : Qt.NoModifier);
                const editor = control("messageEditor");
                tryVerify(() => editor.activeFocus && adapter.draftReady);
                verify(Route.equal(adapter.selectedRoute, route));
                const composer = editor.mapToItem(view.item, editor.width, 0);
                verify(Math.abs(composer.x - (scene.width - Metrics.space12)) < 2);
                compare(control("sendMessage"), null);
                keyClick(Qt.Key_Escape);
                tryVerify(() => list.activeFocus && list.visible);
                verify(!(view.item as MessagesView).composerFocusPending);
                keyClick(Qt.Key_Up);
            }
        }
        function test_reopen_defaults_to_list_and_explicit_route_to_editor() {
            choose("chat-g");
            view.active = false; wait(50); view.active = true;
            tryCompare(view, "status", Loader.Ready);
            (view.item as MessagesView).focusInitial();
            verify(control("conversationList").activeFocus);
            compare(control("conversationList").currentIndex, 1);
            (view.item as MessagesView).focusInitial(true);
            tryVerify(() => control("messageEditor").activeFocus);
            keyClick(Qt.Key_Escape);
            verify(control("conversationList").activeFocus);
            compare(control("conversationList").currentIndex, 1);
            (view.item as MessagesView).focusInitial(true);
            tryVerify(() => control("messageEditor").activeFocus);
            control("messageHistory").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Escape);
            verify(control("conversationList").activeFocus);
        }
        function test_delayed_draft_focus_and_escape_cancels_pending_focus() {
            backend.holdResponses = true;
            verify(messageHub.openConversation(adapter.address("chat-a")));
            (view.item as MessagesView).focusInitial(true);
            backend.release();
            tryVerify(() => adapter.draftReady && control("messageEditor").activeFocus);
            // A delayed draft must not steal focus after Escape.
            adapter.draftReady = false;
            (view.item as MessagesView).focusInitial(true);
            keyClick(Qt.Key_Escape);
            verify(control("conversationList").activeFocus);
            adapter.draftReady = true;
            wait(50);
            verify(control("conversationList").activeFocus);
        }
        function test_pointer_selection_has_no_keyboard_outline() {
            const list = control("conversationList");
            tryVerify(() => list.itemAtIndex(0) !== null);
            keyClick(Qt.Key_J);
            const entry = list.itemAtIndex(0);
            mouseClick(entry, entry.width / 2, entry.height / 2);
            const editor = control("messageEditor");
            tryVerify(() => editor.activeFocus);
            compare(editor.focusReason, Qt.MouseFocusReason);
            verify(!findChild(editor, "focusIndicator").visible);
            keyClick(Qt.Key_H);
            compare(editor.text, "h");
            verify(findChild(editor, "focusIndicator").visible);
            keyClick(Qt.Key_Escape);
            verify(list.activeFocus);
        }
        function test_bubble_width_data() {
            const rows = [];
            for (const width of [320, 640, 980, 1600]) for (const outgoing of [false, true])
                rows.push({tag: width + (outgoing ? "-outgoing" : "-incoming"), width: width, outgoing: outgoing});
            return rows;
        }
        function test_bubble_width(data) {
            scene.width = data.width;
            const message = backend.history["chat-g"][0];
            message.text = "OK";
            if (data.outgoing) { message.direction = "outgoing"; message.status = "sent"; }
            choose("chat-g");
            const history = control("messageHistory");
            tryVerify(() => history.itemAtIndex(0) !== null);
            const row = history.itemAtIndex(0), bubble = row.bubble;
            const body = findChild(row, "messageBody");
            wait(100);
            verify(bubble.width <= history.width / 2);
            verify(body.contentWidth <= body.width + 1);
            compare(body.lineCount, 1);
            const shortWidth = bubble.width;
            if (data.width >= 980) verify(shortWidth < history.width / 2 - 40);
            compare(bubble.x, data.outgoing ? history.width - bubble.width : 0);
            // Model updates and resizing must keep the natural width reactive.
            adapter.messages.setProperty(0, "text", "日本語 🐈 " + "Dłuższa wiadomość. ".repeat(20));
            tryCompare(bubble, "width", history.width / 2);
            verify(bubble.width >= shortWidth);
            verify(body.lineCount > 1);
            verify(body.contentWidth <= body.width + 1);
            adapter.messages.setProperty(0, "text", "OK");
            tryCompare(bubble, "width", shortWidth);
            scene.width = 320;
            tryVerify(() => bubble.width <= history.width / 2);
            findChild(row, "messageActions").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            tryCompare(history, "actionsMessageId", row.messageId);
            tryVerify(() => findChild(row, "deleteMessageLocal") !== null);
            wait(100);
            const action = findChild(row, "deleteMessageLocal");
            const point = action.mapToItem(bubble, 0, 0);
            verify(point.x >= 0 && point.x + action.width <= bubble.width);
            verify(action.contentItem.contentWidth <= action.contentItem.width + 1);
            compare(bubble.width, history.width / 2);
            keyClick(Qt.Key_Return);
            tryCompare(history, "actionsMessageId", "");
        }
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
            tryVerify(() => adapter.canSend);
            keyClick(Qt.Key_A);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier);
            tryCompare(backend, "sentCount", 2);
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
        function verifyLatest() {
            const history = control("messageHistory");
            waitForRendering(view.item);
            tryVerify(() => history.visible && history.count > 0 && !history.restoring && history.atYEnd);
            tryVerify(() => history.itemAtIndex(history.count - 1) !== null);
            const last = history.itemAtIndex(history.count - 1);
            compare(last.messageId, adapter.messages.get(adapter.messages.count - 1).messageId);
            verify(last.y + last.height > history.contentY);
            verify(last.y + last.height <= history.contentY + history.height + 2);
        }
        function test_open_and_reopen_at_latest_data() {
            return [{tag: "wide", width: 980}, {tag: "narrow", width: 320}];
        }
        function test_open_and_reopen_at_latest(data) {
            scene.width = data.width;
            choose();
            verifyLatest();
            const history = control("messageHistory");
            history.forceActiveFocus(Qt.TabFocusReason);
            for (let i = 0; i < 8; i++) keyClick(Qt.Key_K);
            verify(!history.atYEnd);
            verify(!history.followEnd);
            const before = history.contentY;
            backend.incoming("chat-a");
            tryCompare(history, "count", 51); wait(80);
            verify(Math.abs(history.contentY - before) < 2);
            // Recreate the window with the conversation already in memory.
            view.active = false; wait(100);
            view.active = true; tryCompare(view, "status", Loader.Ready);
            verifyLatest();
            choose("chat-g"); choose();
            verifyLatest();
        }
        function test_open_before_view_and_delayed_history_data() {
            return [{tag: "loaded", delayed: false}, {tag: "delayed", delayed: true}];
        }
        function test_open_before_view_and_delayed_history(data) {
            view.active = false; wait(100);
            backend.holdResponses = data.delayed;
            verify(messageHub.openConversation(adapter.address("chat-a")));
            if (!data.delayed) tryCompare(adapter.messages, "count", 50);
            view.active = true; tryCompare(view, "status", Loader.Ready);
            backend.release();
            tryCompare(adapter.messages, "count", 50);
            verifyLatest();
            scene.width = 320; scene.height = 300;
            verifyLatest();
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
