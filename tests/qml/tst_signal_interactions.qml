pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/messages"
import "../../modules/messages/MessageText.js" as MessageText

Item {
    id: scene
    width: 980; height: 720
    MockMessagingBackend { id: backend }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    MockSettingsFile { id: file }
    Settings { id: settings; storage: file }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    Loader { id: view; active: false; anchors.fill: parent; sourceComponent: MessagesView { hub: hub; readingEnabled: true } }
    TestCase {
        name: "SignalInteractions"
        when: windowShown
        function control(name) { return findChild(view.item, name) || findChild(scene.Window.window.contentItem, name); }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            view.active = false; backend.seed();
            backend.configuration = {enabled: true, typingIndicators: true};
            backend.directory = {contacts: [{serviceId: "aci:peer", name: "Alicja"}], groups: [{groupId: "group", members: [{serviceId: "aci:peer"}]}]};
            backend.history["chat-g"] = [Object.assign(backend.message("chat-g", "own", 1), {
                text: "Mój tekst", direction: "outgoing", status: "sent", canEdit: true, canReact: true, canReply: true,
                versionTimestampMs: 1790000000000, sentTimestampMs: 1790000000000, unread: false
            })];
            adapter.clear(); view.active = true;
            tryCompare(adapter, "listLoading", false);
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && !adapter.loading);
            wait(80);
        }
        function cleanup() { backend.release(); settings.cancelEdit(); view.active = false; wait(200); }
        function test_edit_cancel_and_error_keep_normal_draft_and_keyboard_semantics() {
            adapter.editDraft("Zwykły szkic");
            tryVerify(() => !adapter.drafts["chat-g"].pending);
            control("messageActions").click(); tryVerify(() => control("editMessage") !== null); control("editMessage").click();
            tryCompare(control("messageEditor"), "text", "Mój tekst");
            const editor = control("messageEditor"); editor.selectAll();
            for (const c of "hjkl") keyClick(c);
            compare(editor.text, "hjkl"); compare(adapter.draftText, "Zwykły szkic");
            keyClick(Qt.Key_Return, Qt.ShiftModifier); compare(editor.text, "hjkl\n");
            keyClick(Qt.Key_Escape); compare(editor.text, "Zwykły szkic");
            verify(adapter.beginEdit("own"));
            backend.interactionError = "version_conflict";
            adapter.editComposer("Poprawiona"); adapter.sendComposer();
            tryCompare(adapter, "editBusy", false); verify(adapter.editingMessage !== null);
            compare(adapter.editText, "Poprawiona"); compare(adapter.messages.get(0).text, "Mój tekst");
            backend.interactionError = ""; verify(adapter.sendComposer());
            tryVerify(() => adapter.editingMessage === null);
            tryCompare(editor, "text", "Zwykły szkic");
            tryVerify(() => adapter.messages.get(0).edited && adapter.messages.get(0).text === "Poprawiona");
        }
        function test_react_replace_remove_quote_and_unicode_mention() {
            verify(adapter.react("own", "👩‍💻", false));
            tryVerify(() => (JSON.parse(adapter.messages.get(0).reactionsJson)[0] || {}).emoji === "👩‍💻");
            verify(adapter.react("own", "❤️", false));
            tryVerify(() => (JSON.parse(adapter.messages.get(0).reactionsJson)[0] || {}).emoji === "❤️");
            verify(adapter.react("own", "❤️", true));
            tryCompare(adapter.messages.get(0), "reactionsJson", "[]");
            adapter.replyTo("own"); verify(adapter.quotedMessage !== null);
            adapter.editComposer("👩‍💻 "); adapter.addMention({serviceId: "aci:peer", name: "Alicja"}, 6);
            compare(adapter.composeMentions[0].start, 6); compare(adapter.composeMentions[0].length, 7);
            verify(adapter.sendComposer()); tryCompare(backend, "sentCount", 1);
            const sent = backend.calls.filter(c => c.method === "message.send")[0].params;
            compare(sent.quoteMessageId, "own"); compare(sent.mentions[0].start, 6);
        }
        function test_typing_only_focused_editor_rate_limited_and_stops_on_blur_lock_send() {
            const editor = control("messageEditor"); editor.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_A); keyClick(Qt.Key_B); keyClick(Qt.Key_C);
            compare(backend.calls.filter(c => c.method === "typing.set" && c.params.active).length, 1);
            keyClick(Qt.Key_Escape);
            verify(control("conversationList").activeFocus);
            compare(backend.calls.filter(c => c.method === "typing.set" && !c.params.active).length, 1);
            editor.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_D);
            (view.item as MessagesView).readingEnabled = false;
            verify(!adapter.editorActive); verify(!adapter.typingSent);
            (view.item as MessagesView).readingEnabled = true;
            editor.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_E);
            keyClick(Qt.Key_Return); tryCompare(backend, "sentCount", 1);
            verify(!adapter.typingSent);
            backend.configuration = {enabled: true, typingIndicators: false}; keyClick(Qt.Key_F);
            verify(!adapter.typingSent);
        }
        function test_picker_and_saved_composition_survive_adapter_recreation() {
            const editor = control("messageEditor"); editor.forceActiveFocus(Qt.TabFocusReason);
            adapter.editComposer("👩‍💻 "); editor.cursorPosition = 6;
            control("mentionMember").click();
            tryVerify(() => control("mentionChoice") !== null);
            control("mentionChoice").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            compare(adapter.composerText, "👩‍💻 @Alicja ");
            adapter.replyTo("own");
            tryVerify(() => !adapter.drafts["chat-g"].pending && !adapter.drafts["chat-g"].dirty);
            adapter.clear(); hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && adapter.quotedMessage !== null);
            compare(adapter.composeMentions[0].start, 6); compare(adapter.quotedMessage.messageId, "own");
        }
        function test_safe_styles_and_live_accents() {
            compare(MessageText.render("<img src=x> &", [], []), "&lt;img src=x&gt; &amp;");
            compare(MessageText.render("tajne", [{start: 0, length: 5, style: "SPOILER"}], []), "•••");
            compare(MessageText.render("tekst", [{start: 0, length: 5, style: "BOLD"}], []), "<b>tekst</b>");
            adapter.beginEdit("own");
            // Compare colors without the TextArea's blinking caret.
            control("messageHistory").forceActiveFocus(Qt.TabFocusReason);
            wait(Metrics.panelFade + 32);
            const editor = control("messageEditor"); waitForRendering(view.item);
            const before = grabImage(view.item);
            settings.beginEdit(); settings.setColor("accent", "#89b4fa"); settings.setColor("accentSecondary", "#f38ba8");
            waitForRendering(view.item); const changed = grabImage(view.item); verify(!before.equals(changed));
            settings.cancelEdit(); waitForRendering(view.item);
            const restored = grabImage(view.item);
            compare(restored.size, before.size);
            // Rebuilding the group gradient can round a channel by one byte.
            // Check every rendered pixel, including the editor and message.
            for (let y = 0; y < before.height; y++) for (let x = 0; x < before.width; x++) {
                if (Math.abs(before.red(x, y) - restored.red(x, y)) > 1
                    || Math.abs(before.green(x, y) - restored.green(x, y)) > 1
                    || Math.abs(before.blue(x, y) - restored.blue(x, y)) > 1
                    || before.alpha(x, y) !== restored.alpha(x, y)) fail("Accent restore differs at " + x + "," + y);
            }
            editor.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Escape); verify(!adapter.editingMessage);
        }
    }
}
