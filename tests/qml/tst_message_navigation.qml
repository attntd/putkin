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
    MockMessagingBackend { id: backend }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    Loader { id: view; active: false; anchors.fill: parent; sourceComponent: MessagesView { hub: hub; readingEnabled: true } }
    TestCase {
        name: "MessageNavigation"
        when: windowShown
        function control(name) { return findChild(view.item, name) || findChild(scene.Window.window.contentItem, name); }
        function editor() { return control("messageEditor"); }
        function focused() { return scene.Window.window.activeFocusItem; }
        function history() { return control("messageHistory"); }
        function open(key = Qt.Key_L) {
            keyClick(key, key === Qt.Key_Enter ? Qt.KeypadModifier : Qt.NoModifier);
            tryVerify(() => adapter.draftReady && !adapter.loading && editor().activeFocus);
            verify(waitForPolish(scene.Window.window));
        }
        function normal() {
            verify(editor().readOnly); verify(!editor().cursorVisible);
            verify(!(view.item as MessagesView).insertMode);
        }
        function capture(name) {
            verify(waitForPolish(scene.Window.window)); waitForRendering(view.item);
            grabImage(view.item).save(Qt.resolvedUrl("../../docs/evidence/vim-conversations-20260928/" + name + ".png").toString().replace("file://", ""));
        }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            scene.width = 980; view.active = false; backend.seed();
            backend.configuration = {enabled: true, typingIndicators: true};
            backend.history["chat-a"].forEach((m, i) => Object.assign(m, {
                canReact: true, canReply: true, canDeleteLocal: true, canForward: true,
                orderSequence: i + 1, versionTimestampMs: m.sortTimestampMs, sentTimestampMs: m.sortTimestampMs
            }));
            adapter.clear(); view.active = true;
            tryCompare(view, "status", Loader.Ready); tryCompare(adapter, "listLoading", false);
            (view.item as MessagesView).focusInitial(); verify(waitForPolish(scene.Window.window));
        }
        function cleanup() { backend.release(); view.active = false; wait(250); }
        function test_keyboard_entry_normal_data() {
            const cases = [];
            for (const width of [980, 320]) for (const key of [Qt.Key_L, Qt.Key_Return, Qt.Key_Enter])
                cases.push({tag: width + "-" + key, width: width, key: key});
            return cases;
        }
        function test_keyboard_entry_normal(data) {
            scene.width = data.width; open(data.key); normal();
            verify(findChild(editor(), "focusIndicator").visible);
            compare(backend.sentCount, 0); compare(adapter.draftText, "");
            keyClick(Qt.Key_Escape); verify(control("conversationList").activeFocus);
        }
        function test_navigation_editor_attachment_bubbles_and_insert() {
            open(); keyClick(Qt.Key_H); verify(control("attachFiles").activeFocus); normal();
            keyClick(Qt.Key_L); verify(editor().activeFocus); normal();
            keyClick(Qt.Key_K); tryCompare(focused(), "objectName", "messageBubble");
            compare(focused().messageId, "m-179");
            keyClick(Qt.Key_K); compare(focused().messageId, "m-178");
            keyClick(Qt.Key_J); compare(focused().messageId, "m-179");
            keyClick(Qt.Key_J); verify(editor().activeFocus); normal();
            keyClick(Qt.Key_K); capture("normal-bubble");
            keyClick(Qt.Key_I); verify(editor().activeFocus); verify(!editor().readOnly); verify(editor().cursorVisible);
            for (const c of "hjkli") keyClick(c);
            compare(editor().text, "hjkli"); compare(backend.sentCount, 0);
            capture("insert");
            keyClick(Qt.Key_Escape); normal(); verify(editor().activeFocus); capture("normal-editor");
            compare(adapter.draftText, "hjkli"); verify(!adapter.editorActive); verify(!adapter.typingSent);
            keyClick(Qt.Key_Escape); verify(control("conversationList").activeFocus);
        }
        function test_i_from_attachment_and_header() {
            open(); keyClick(Qt.Key_H); keyClick(Qt.Key_I);
            verify(editor().activeFocus); verify(!editor().readOnly);
            keyClick(Qt.Key_Escape); normal();
            control("conversationDetails").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_I); verify(editor().activeFocus); verify(!editor().readOnly);
        }
        function test_space_reaction_returns_to_same_bubble() {
            open(); keyClick(Qt.Key_K); const id = focused().messageId;
            keyClick(Qt.Key_Space); tryCompare(control("messageActionPopup"), "opened", true);
            keyClick(Qt.Key_Return); tryCompare(control("messageActionPopup"), "visible", false);
            tryVerify(() => focused().objectName === "messageBubble" && focused().messageId === id);
            normal(); compare(backend.sentCount, 0);
            const reactions = backend.calls.filter(c => c.method === "message.react");
            compare(reactions.length, 1); compare(reactions[0].params.messageId, id);
            keyClick(Qt.Key_Return); tryCompare(control("messageActionPopup"), "opened", true);
            keyClick(Qt.Key_Escape); tryCompare(control("messageActionPopup"), "visible", false);
            tryVerify(() => focused().objectName === "messageBubble" && focused().messageId === id);
            keyClick(Qt.Key_Escape); verify(control("conversationList").activeFocus);
        }
        function test_mouse_enters_insert_without_keyboard_frame() {
            open(); normal();
            mouseClick(editor(), 25, editor().height / 2);
            verify(editor().activeFocus); verify(!editor().readOnly); verify(editor().cursorVisible);
            verify(!findChild(editor(), "focusIndicator").visible);
            keyClick(Qt.Key_A); compare(editor().text, "a");
            keyClick(Qt.Key_Escape); normal(); verify(findChild(editor(), "focusIndicator").visible);
        }
        function test_pointer_on_history_clears_bubble_keyboard_frame() {
            open(); keyClick(Qt.Key_K);
            const row = focused(); compare(row.focusReason, Qt.TabFocusReason);
            mouseClick(history(), history().width / 2, history().height / 2);
            compare(row.focusReason, Qt.MouseFocusReason);
            keyClick(Qt.Key_K); compare(focused().focusReason, Qt.TabFocusReason);
        }
        function test_toolbar_keyboard_return_after_pointer_uses_focus_frame() {
            open(); keyClick(Qt.Key_K); const row = focused();
            mouseClick(findChild(row, "reactMessage"));
            tryCompare(control("messageActionPopup"), "opened", true);
            keyClick(Qt.Key_Escape); tryCompare(control("messageActionPopup"), "visible", false);
            tryCompare(focused(), "objectName", "reactMessage");
            keyClick(Qt.Key_K); compare(focused(), row); compare(row.focusReason, Qt.TabFocusReason);
            mouseClick(history(), history().width / 2, history().height / 2);
            compare(row.focusReason, Qt.MouseFocusReason);
        }
        function test_normal_does_not_type_or_send_and_insert_keeps_shift_enter() {
            open(); adapter.editDraft("Szkic"); tryCompare(editor(), "text", "Szkic");
            for (const c of "abcv") keyClick(c);
            keyClick(Qt.Key_Backspace); keyClick(Qt.Key_Delete); keyClick(Qt.Key_Space);
            compare(editor().text, "Szkic"); compare(backend.sentCount, 0);
            keyClick(Qt.Key_I); editor().cursorPosition = editor().length;
            keyClick(Qt.Key_Return, Qt.ShiftModifier); compare(editor().text, "Szkic\n");
            keyClick(Qt.Key_Return); tryCompare(backend, "sentCount", 1);
            tryCompare(editor(), "text", ""); verify(!editor().readOnly);
        }
        function test_refresh_and_pagination_keep_bubble_identity_and_insert_focus() {
            open(); keyClick(Qt.Key_K); keyClick(Qt.Key_K); const id = focused().messageId;
            adapter.loadMore(); tryCompare(adapter, "loading", false);
            tryVerify(() => focused().objectName === "messageBubble" && focused().messageId === id);
            backend.incoming("chat-a");
            tryVerify(() => adapter.messages.count > 100);
            tryVerify(() => focused().objectName === "messageBubble" && focused().messageId === id);
            keyClick(Qt.Key_I); keyClick(Qt.Key_X); backend.incoming("chat-a");
            tryCompare(adapter, "messageRequest", ""); wait(80);
            verify(editor().activeFocus); verify(!editor().readOnly); compare(editor().text, "x");
        }
        function test_normal_search_keeps_literal_letters() {
            control("conversationSearch").forceActiveFocus(Qt.TabFocusReason);
            for (const c of "hjkli") keyClick(c);
            compare(control("conversationSearch").text, "hjkli");
        }
    }
}
