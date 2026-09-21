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
        name: "SignalRetention"
        when: windowShown
        function control(name) { return findChild(view.item, name) || findChild(scene.Window.window.contentItem, name); }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            view.active = false; backend.seed();
            backend.configuration = {enabled: true, typingIndicators: true};
            backend.directory = {contacts: [{serviceId: "aci:peer", name: "Alicja"}], groups: [{groupId: "group", members: [{serviceId: "aci:peer"}]}]};
            backend.history["chat-g"] = [Object.assign(backend.message("chat-g", "own", 1), {
                text: "Mój tekst", direction: "outgoing", status: "sent", canEdit: true, canReact: true, canReply: true, canDeleteLocal: true, canDeleteRemote: true,
                versionTimestampMs: 1790000000000, sentTimestampMs: 1790000000000, unread: false
            })];
            adapter.clear(); view.active = true;
            tryCompare(adapter, "listLoading", false);
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && !adapter.loading);
            wait(80);
        }
        function cleanup() { backend.release(); settings.cancelEdit(); view.active = false; wait(200); }
        function test_local_and_everyone_buttons_have_distinct_scope_and_keyboard() {
            control("messageActions").click();
            tryVerify(() => control("deleteMessageLocal") !== null);
            control("deleteMessageLocal").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryCompare(adapter.messages, "count", 0);
            compare(backend.calls.filter(c => c.method === "message.delete")[0].params.scope, "local");
        }
        function test_remote_button_and_shared_accent_preview() {
            control("messageActions").click();
            tryVerify(() => control("deleteMessageEveryone") !== null);
            waitForRendering(view.item); const before = grabImage(view.item);
            settings.beginEdit(); settings.setColor("accent", "#89b4fa"); settings.setColor("accentSecondary", "#f38ba8");
            waitForRendering(view.item); verify(!before.equals(grabImage(view.item)));
            settings.cancelEdit();
            control("deleteMessageEveryone").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryCompare(adapter.messages, "count", 0);
            const call = backend.calls.find(c => c.method === "message.delete");
            compare(call.params.scope, "everyone"); verify(call.params.operationId.length > 0);
        }
        function test_expiration_setting_uses_explicit_duration() {
            control("conversationDetails").click();
            tryVerify(() => control("conversationExpiration") !== null);
            control("conversationExpiration").click();
            tryVerify(() => control("expirationChoice300") !== null);
            control("expirationChoice300").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryVerify(() => adapter.selectedConversation.expirationSeconds === 300);
            compare(backend.calls.filter(c => c.method === "conversation.expiration")[0].params.seconds, 300);
        }
        function test_redaction_clears_busy_editor_quote_and_late_page() {
            adapter.editDraft("Zwykły szkic");
            tryVerify(() => !adapter.drafts["chat-g"].pending);
            const stale = Object.assign({}, backend.history["chat-g"][0]);
            verify(adapter.beginEdit("own")); adapter.editComposer("Wersja w edytorze"); adapter.editBusy = true;
            backend.event("message.redacted", {accountId: backend.accountId, conversationId: "chat-g", messageId: "own"});
            compare(adapter.editingMessage, null); compare(adapter.editText, ""); compare(adapter.messages.count, 0);
            compare(adapter.draftText, "Zwykły szkic");
            adapter.merge([stale], false); compare(adapter.messages.count, 0);
        }
        function test_redaction_closes_media_preview_and_drops_image_reference() {
            const url = Qt.resolvedUrl("../fixtures/signal/media/image.png").toString();
            const attachment = {attachment_id: "fixture", filename: "image.png", content_type: "image/png", url: url, preview: url, thumbnail: url, state: "ready", errorCode: "", size_bytes: 128};
            adapter.messages.setProperty(0, "attachmentsJson", JSON.stringify([attachment]));
            (view.item as MessagesView).previewAttachment = attachment;
            tryVerify(() => control("mediaPreview") !== null);
            wait(100);
            backend.event("message.redacted", {accountId: backend.accountId, conversationId: "chat-g", messageId: "own"});
            compare((view.item as MessagesView).previewAttachment, null);
            tryVerify(() => control("mediaPreview") === null);
        }
        function test_redaction_removes_quote_without_overwriting_draft() {
            adapter.editDraft("Szkic"); adapter.replyTo("own");
            tryVerify(() => !adapter.drafts["chat-g"].pending && !adapter.drafts["chat-g"].dirty);
            verify(adapter.quotedMessage !== null);
            backend.event("message.redacted", {accountId: backend.accountId, conversationId: "chat-g", messageId: "own"});
            compare(adapter.quotedMessage, null); compare(adapter.draftText, "Szkic");
            verify(!adapter.drafts["chat-g"].composition.quoteMessageId);
        }
    }
}
