pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/messages"

Item {
    id: scene
    width: 980; height: 720
    MockMessagingBackend { id: backend; groupsEnabled: true; callsEnabled: true }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    Loader { id: view; active: false; anchors.fill: parent; sourceComponent: MessagesView { hub: hub } }
    TestCase {
        name: "Conversations"
        when: windowShown
        function control(name) { return findChild(view.item, name) || findChild(scene.Window.window.contentItem, name); }
        function list() { return control("conversationList"); }
        function screenshot(name) {
            if (control("conversationMenu").closing) tryCompare(control("conversationMenu"), "visible", false);
            verify(waitForPolish(scene.Window.window));
            waitForRendering(view.item);
            grabImage(scene.Window.window.contentItem).save(Qt.resolvedUrl("../../docs/evidence/conversations-20260928/" + name + ".png").toString().replace("file://", ""));
        }
        function click(name) { const b = control(name); verify(b !== null); verify(waitForPolish(scene.Window.window)); mouseClick(b, b.width / 2, b.height / 2); }
        function select(cid = "chat-a") {
            hub.openConversation(adapter.address(cid));
            tryVerify(() => adapter.selectedRoute !== null && adapter.selectedRoute.conversationId === cid && adapter.draftReady && !adapter.loading);
            verify(waitForPolish(scene.Window.window));
        }
        function menu(keyboard = true) {
            if (control("conversationMenu").closing) tryCompare(control("conversationMenu"), "visible", false);
            if (keyboard) { list().forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Menu); }
            else { list().forceLayout(); mouseClick(list().currentItem, 16, 16, Qt.RightButton); }
            tryCompare(control("conversationMenu"), "opened", true);
        }
        function outlines(item) {
            let count = item.objectName === "focusIndicator" && item.visible ? 1 : 0;
            for (const child of item.children || []) count += outlines(child);
            return count;
        }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            scene.width = 980; scene.height = 720; view.active = false;
            backend.seed(); backend.rows.forEach(c => { c.canRead = true; c.requestState = c.kind === "group" ? "member" : "accepted"; });
            adapter.clear(); service.calls.refresh(); view.active = true;
            tryCompare(view, "status", Loader.Ready); tryCompare(adapter, "listLoading", false); tryCompare(adapter, "layoutBusy", false);
            tryCompare(service.calls, "available", true);
            (view.item as MessagesView).focusInitial(); verify(waitForPolish(scene.Window.window)); wait(80);
        }
        function cleanup() { backend.release(); view.active = false; wait(250); }
        function test_cards_collapse_preserves_route_draft_and_survives_recreation() {
            select(); adapter.editDraft("Szkic hjkl");
            const wide = list().width;
            click("toggleConversationCards"); tryCompare(adapter, "cardsCollapsed", true);
            tryVerify(() => list().width < 80);
            compare(adapter.selectedRoute.conversationId, "chat-a"); compare(adapter.draftText, "Szkic hjkl");
            verify(!control("conversationSearch").visible);
            screenshot("rail");
            view.active = false; wait(30); adapter.clear(); service.calls.refresh(); view.active = true;
            tryCompare(view, "status", Loader.Ready); tryCompare(adapter, "cardsCollapsed", true);
            (view.item as MessagesView).focusInitial();
            tryVerify(() => list().width < 80);
            click("toggleConversationCards"); tryCompare(adapter, "cardsCollapsed", false);
            tryCompare(list(), "width", wide);
        }
        function test_compact_search_expands_and_keeps_letters() {
            click("toggleConversationCards"); tryCompare(adapter, "cardsCollapsed", true);
            list().forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Slash);
            tryVerify(() => control("conversationSearch").visible && control("conversationSearch").activeFocus);
            for (const letter of "hjkl") keyClick(letter);
            compare(control("conversationSearch").text, "hjkl"); compare(list().count, 0);
            keyClick(Qt.Key_Escape); verify(list().activeFocus);
            keyClick(Qt.Key_K); verify(control("conversationSearch").activeFocus);
        }
        function test_keyboard_menu_navigation_and_pointer_remove_frame() {
            menu(); tryVerify(() => control("archiveConversation").activeFocus);
            compare(outlines(control("archiveConversation")), 1);
            keyClick(Qt.Key_J); verify(control("pinConversation").activeFocus);
            keyClick(Qt.Key_K); verify(control("archiveConversation").activeFocus);
            keyClick(Qt.Key_H); tryCompare(control("conversationMenu"), "visible", false);
            tryVerify(() => list().activeFocus); compare(list().focusReason, Qt.TabFocusReason);
            menu(false); tryVerify(() => control("archiveConversation").activeFocus);
            compare(outlines(control("archiveConversation")), 0);
            compare(outlines(list()), 0);
            keyClick(Qt.Key_Escape); tryCompare(control("conversationMenu"), "visible", false);
            tryCompare(list(), "focusReason", Qt.TabFocusReason);
        }
        function test_archive_active_and_restore_from_distinct_list() {
            select(); adapter.editDraft("Zachowaj mnie");
            control("conversationOptions").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryCompare(control("conversationMenu"), "opened", true); keyClick(Qt.Key_Return);
            tryCompare(adapter, "selectedConversation", null); tryCompare(list(), "count", 1);
            compare(adapter.nextCursor, null); verify(!control("messageHistory").visible);
            tryVerify(() => list().activeFocus); compare(list().focusReason, Qt.TabFocusReason);
            verify(backend.history["chat-a"].length === 180);
            click("showConversationArchive"); tryCompare(list(), "count", 1);
            compare((view.item as MessagesView).filtered[0].conversationId, "chat-a");
            screenshot("archive");
            menu(); compare(control("archiveConversation").text, "Przywróć z archiwum"); keyClick(Qt.Key_Return);
            tryCompare(list(), "count", 0);
            click("showConversationArchive"); tryCompare(list(), "count", 2);
            select(); compare(adapter.draftText, "Zachowaj mnie");
        }
        function test_pin_reorders_without_changing_focused_conversation() {
            list().forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_J); compare(list().currentIndex, 1);
            menu(); keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            tryVerify(() => hub.conversations[0].conversationId === "chat-g" && hub.conversations[0].pinned);
            tryCompare(list(), "currentIndex", 0);
            tryVerify(() => list().activeFocus);
            compare((view.item as MessagesView).filtered[list().currentIndex].conversationId, "chat-g");
            screenshot("pinned");
        }
        function test_unread_and_mute_target_context_row_without_opening() {
            menu(); click("readConversation"); tryCompare(hub, "unreadCount", 1);
            compare(adapter.selectedRoute, null);
            menu(); compare(control("readConversation").text, "Oznacz jako nieprzeczytaną"); click("readConversation");
            tryVerify(() => adapter.conversations[0].markedUnread); compare(hub.unreadCount, 2);
            menu(); click("menuMuteConversation"); tryVerify(() => adapter.conversations[0].muted);
            verify(!backend.calls.some(c => c.method === "conversation.block"));
        }
        function test_mark_active_unread_returns_to_list_without_reading() {
            select(); backend.rows[0].unreadCount = 0; adapter.refreshList(); tryCompare(adapter.selectedConversation, "unreadCount", 0);
            click("conversationOptions"); tryCompare(control("conversationMenu"), "opened", true); click("readConversation");
            tryCompare(adapter, "selectedRoute", null);
            tryVerify(() => adapter.conversations[0].markedUnread);
            wait(350); verify(adapter.conversations[0].markedUnread);
        }
        function test_failed_archive_does_not_drop_selection_or_messages() {
            select(); backend.conversationError = "storage_error";
            click("conversationOptions"); tryCompare(control("conversationMenu"), "opened", true); click("archiveConversation");
            tryVerify(() => adapter.lastError.length > 0);
            compare(adapter.selectedRoute.conversationId, "chat-a"); compare(list().count, 2); compare(adapter.messages.count, 50);
        }
        function test_header_focus_call_and_details_return_data() {
            return [{tag: "wide", width: 980}, {tag: "narrow", width: 320}];
        }
        function test_header_focus_call_and_details_return(data) {
            scene.width = data.width; select();
            const details = control("conversationDetails"); details.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_L); verify(control("startCall").activeFocus);
            keyClick(Qt.Key_L); verify(control("conversationOptions").activeFocus);
            keyClick(Qt.Key_H); keyClick(Qt.Key_H); verify(details.activeFocus);
            keyClick(Qt.Key_Return); tryVerify(() => control("closeConversationDetails").activeFocus);
            keyClick(Qt.Key_Escape); tryVerify(() => details.activeFocus);
            for (const name of ["conversationDetails", "startCall", "conversationOptions"]) {
                const b = control(name), p = b.mapToItem(view.item, 0, 0);
                verify(p.x >= 0 && p.x + b.width <= scene.width);
            }
            screenshot("header-" + data.tag);
        }
        function test_avatars_lazy_cache_and_identity_across_refresh() {
            tryVerify(() => backend.calls.filter(c => c.method === "directory.avatar").length === 2);
            const before = backend.calls.filter(c => c.method === "directory.avatar").length;
            adapter.refreshList(); tryCompare(adapter, "listLoading", false); wait(50);
            compare(backend.calls.filter(c => c.method === "directory.avatar").length, before);
            list().forceLayout();
            const avatar = findChild(list().itemAtIndex(0), "avatarImage");
            compare(avatar.source.toString(), "");
            backend.rows[0].avatar = Qt.resolvedUrl("../../assets/material/person.svg").toString();
            adapter.refreshList(); tryCompare(adapter, "listLoading", false); list().forceLayout();
            tryCompare(findChild(list().itemAtIndex(0), "avatarImage"), "status", Image.Ready);
        }
        function test_resize_compact_to_narrow_keeps_card_preference() {
            click("toggleConversationCards"); tryCompare(adapter, "cardsCollapsed", true);
            scene.width = 320; wait(80);
            verify(control("conversationSearch").visible); verify(list().width > 200);
            list().forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return); tryVerify(() => control("messageEditor").activeFocus);
            keyClick(Qt.Key_Escape); verify(list().visible && list().activeFocus);
            scene.width = 980; tryVerify(() => list().width < 80); verify(adapter.cardsCollapsed);
        }
    }
}
