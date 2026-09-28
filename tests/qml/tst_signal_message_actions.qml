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
    MockSettingsFile { id: file }
    Settings { id: settings; storage: file }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    Loader { id: view; active: false; anchors.fill: parent; sourceComponent: MessagesView { hub: hub; readingEnabled: true } }
    TextEdit { id: clipboardReader; visible: false }
    TestCase {
        name: "SignalMessageActions"
        when: windowShown
        function control(name) { return findChild(view.item, name) || findChild(scene.Window.window.contentItem, name); }
        function row(index = 0) { const h = control("messageHistory"); h.forceLayout(); return h.itemAtIndex(index); }
        function show(name = "messageActions", index = 0) {
            const item = row(index), button = findChild(item, name);
            mouseMove(item, item.width / 2, item.height / 2);
            mouseClick(button, button.width / 2, button.height / 2);
            tryCompare(control("messageActionPopup"), "opened", true);
            return item;
        }
        function choose(name) {
            tryVerify(() => control(name) !== null);
            const button = control(name);
            mouseClick(button, button.width / 2, button.height / 2);
        }
        function close() {
            keyClick(Qt.Key_Escape);
            tryCompare(control("messageActionPopup"), "visible", false);
        }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            scene.width = 980; scene.height = 720; view.active = false; backend.seed();
            backend.history["chat-g"] = [Object.assign(backend.message("chat-g", "own", 1), {
                text: "Mój tekst 🐈", direction: "outgoing", status: "sent", canEdit: true, canReact: true,
                canReply: true, canDeleteLocal: true, canDeleteRemote: true, canPin: true, canForward: true,
                versionTimestampMs: 1790000002000, sentTimestampMs: 1790000002000, sortTimestampMs: 1790000002000,
                orderSequence: 1, unread: false
            }), Object.assign(backend.message("chat-g", "peer", 2), {
                text: "Odpowiedź po chwili", canReact: true, canReply: true, canDeleteLocal: true, canPin: true, canForward: true,
                versionTimestampMs: 1790000001000, sentTimestampMs: 1790000001000, sortTimestampMs: 1790000001000,
                orderSequence: 2, unread: false
            })];
            adapter.clear(); view.active = true;
            tryCompare(adapter, "listLoading", false);
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && !adapter.loading);
            tryCompare(control("messageHistory"), "count", 2); wait(100);
        }
        function cleanup() { backend.release(); view.active = false; settings.cancelEdit(); clipboardReader.text = ""; wait(250); }
        function test_order_uses_reception_and_hhmm_survives_ack_and_incremental_merge() {
            compare(adapter.messages.get(0).messageId, "own"); compare(adapter.messages.get(1).messageId, "peer");
            compare(adapter.messages.get(0).time, adapter.messages.get(1).time);
            verify(/^\d{2}:\d{2}$/.test(adapter.messages.get(0).time));
            const original = backend.history["chat-g"][0];
            original.sortTimestampMs += 2000;
            backend.event("message.changed", {accountId: backend.accountId, conversationId: "chat-g", messageId: "own"});
            tryCompare(adapter.messages.get(0), "timestamp", original.sortTimestampMs);
            compare(adapter.messages.get(1).messageId, "peer");
            adapter.merge(backend.history["chat-g"].slice().reverse(), false);
            compare(adapter.messages.get(0).messageId, "own"); compare(adapter.messages.get(1).messageId, "peer");
        }
        function test_icons_outside_bubble_and_popup_does_not_resize_history_data() {
            return [{tag: "wide-outgoing", width: 980, index: 0}, {tag: "narrow-incoming", width: 320, index: 1}];
        }
        function test_icons_outside_bubble_and_popup_does_not_resize_history(data) {
            scene.width = data.width; wait(100);
            const item = row(data.index), box = item.bubble, h = control("messageHistory");
            const initial = {width: box.width, height: box.height, scroll: h.contentY};
            const buttons = ["reactMessage", "replyMessage", "messageActions"].map(name => findChild(item, name));
            for (const button of buttons) {
                const p = button.mapToItem(box, 0, 0);
                verify(p.x + button.width <= 0 || p.x >= box.width);
                verify(Math.abs(p.y + button.height / 2 - box.height / 2) < 1, "action is vertically centered on its bubble");
                const inside = button.mapToItem(h, 0, 0); verify(inside.x >= 0 && inside.x + button.width <= h.width);
            }
            show("messageActions", data.index);
            compare(box.width, initial.width); compare(box.height, initial.height); compare(h.contentY, initial.scroll);
            const popup = control("messageActionPopup");
            verify(popup.x >= 0 && popup.x + popup.width <= scene.width);
            verify(popup.y >= 0 && popup.y + popup.height <= scene.height);
            verify(!findChild(item, "deleteMessage"));
            compare(control("messageActionList").count, data.index === 0 ? 7 : 6);
            grabImage(scene.Window.window.contentItem).save(Qt.resolvedUrl("../../docs/evidence/signal-message-polish-20260926/menu-" + data.tag + ".png").toString().replace("file://", ""));
            close(); compare(box.height, initial.height);
        }
        function test_keyboard_menu_navigation_escape_and_pointer_focus() {
            const button = findChild(row(), "messageActions");
            button.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryCompare(control("messageActionPopup"), "opened", true);
            tryVerify(() => control("forwardMessage").activeFocus);
            keyClick(Qt.Key_J); verify(control("editMessage").activeFocus);
            keyClick(Qt.Key_K); verify(control("forwardMessage").activeFocus);
            compare(control("messageActionPopup").reason, Qt.TabFocusReason);
            verify(control("messageActionPopup").returnFocus, "Restore allowed before Escape");
            close(); tryVerify(() => button.activeFocus, 1000, "Escape returns focus to the toolbar");
            verify(control("messageActionPopup").returnFocus, "Restore allowed after Escape");
            tryCompare(button, "focusReason", Qt.TabFocusReason);
            tryVerify(() => findChild(button.background, "focusIndicator").visible, 1000, "Keyboard frame after Escape");
            show(); verify(!findChild(control("forwardMessage"), "focusIndicator").visible);
            const editor = control("messageEditor");
            mouseClick(editor, editor.width / 2, editor.height / 2);
            tryCompare(control("messageActionPopup"), "visible", false);
            verify(!findChild(button.background, "focusIndicator").visible);
            mouseClick(editor, editor.width / 2, editor.height / 2);
            compare(scene.Window.window.activeFocusItem.objectName, "messageEditor");
            verify(!findChild(control("messageEditor"), "focusIndicator").visible);
        }
        function test_reaction_row_full_picker_replace_remove_and_reply() {
            const box = row().bubble, initialHeight = box.height;
            show("reactMessage");
            compare(box.height, initialHeight);
            grabImage(scene.Window.window.contentItem).save(Qt.resolvedUrl("../../docs/evidence/signal-message-polish-20260926/reactions.png").toString().replace("file://", ""));
            choose("reactionChoice");
            tryVerify(() => JSON.parse(adapter.messages.get(0).reactionsJson).length === 1);
            compare(JSON.parse(adapter.messages.get(0).reactionsJson)[0].emoji, "❤️");
            tryCompare(control("messageActionPopup"), "visible", false);
            show("reactMessage"); choose("allReactions");
            const search = control("emojiSearch"); verify(search.activeFocus);
            for (const c of "hjkl") keyClick(c);
            compare(search.text, "hjkl"); compare(backend.calls.filter(c => c.method === "message.react").length, 1);
            search.text = "grinning"; tryVerify(() => control("emojiGrid").count > 0);
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return);
            tryCompare(control("messageActionPopup"), "visible", false);
            const emoji = JSON.parse(adapter.messages.get(0).reactionsJson)[0].emoji; verify(emoji !== "❤️");
            show("reactMessage");
            const chooser = control("reactionChoice");
            // Remove a reaction outside the preferred six using the seventh cell.
            const strip = chooser.parent; const last = strip.children.filter(c => c.objectName === "reactionChoice").pop();
            mouseClick(last, last.width / 2, last.height / 2);
            tryCompare(adapter.messages.get(0), "reactionsJson", "[]");
            tryCompare(control("messageActionPopup"), "visible", false);
            const reply = findChild(row(), "replyMessage"); mouseMove(reply, 10, 10); mouseClick(reply, 10, 10);
            verify(adapter.quotedMessage !== null); compare(adapter.quotedMessage.messageId, "own");
            verify(control("messageEditor").activeFocus);
        }
        function test_copy_plain_text_and_info_popup() {
            show(); choose("copyMessage");
            clipboardReader.paste(); compare(clipboardReader.text, "Mój tekst 🐈");
            tryCompare(control("messageActionPopup"), "visible", false);
            show(); choose("messageInfo");
            tryCompare(control("messageInformation"), "visible", true);
            tryVerify(() => control("messageInformation").activeFocus); close();
        }
        function test_reaction_chip_shows_only_its_people_and_refreshes() {
            const message = backend.history["chat-g"][0];
            message.reactions = [
                {emoji: "❤️", count: 2, mine: true, people: [{name: "Alicja", serviceId: "aci:peer"}, {name: "Ty", serviceId: "aci:self"}]},
                {emoji: "👍", count: 1, mine: false, people: [{name: "Łukasz", serviceId: "aci:other"}]}
            ];
            adapter.merge([message], false); wait(100);
            show("messageReaction");
            const people = control("reactionPeople");
            verify(people && people.visible && people.activeFocus);
            const labels = people.contentItem.children[0].children.filter(item => item.objectName === "reactionPerson");
            compare(labels.map(item => item.text), ["Alicja", "Ty"]);
            verify(!control("messageInformation"));
            verify(!control("messageActionList").visible);
            grabImage(scene.Window.window.contentItem).save(Qt.resolvedUrl("../../docs/evidence/signal-message-polish-20260926/reaction-people.png").toString().replace("file://", ""));
            close();
            verify(findChild(row(), "messageReaction").activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(control("messageActionPopup"), "opened", true);
            message.reactions[0].people = [{name: "Alicja", serviceId: "aci:peer"}];
            adapter.merge([message], false);
            tryVerify(() => control("reactionPeople").contentItem.children[0].children.filter(item => item.objectName === "reactionPerson").length === 1);
            message.reactions = message.reactions.slice(1);
            adapter.merge([message], false);
            tryCompare(control("messageActionPopup"), "visible", false);
        }
        function test_pin_duration_display_jump_and_unpin() {
            show(); choose("pinMessage"); choose("pin24h");
            tryCompare(control("messageActionPopup"), "visible", false);
            tryVerify(() => control("pinnedMessage") !== null);
            const call = backend.calls.filter(c => c.method === "message.pin")[0];
            compare(call.params.durationSeconds, 86400); compare(call.params.remove, false);
            choose("pinnedMessage"); verify(control("messageHistory").activeFocus);
            show(); tryCompare(control("pinMessage"), "text", "Odepnij"); choose("pinMessage");
            tryVerify(() => adapter.selectedConversation.pinnedMessages.length === 0);
        }
        function test_forward_confirmation_selection_and_target_draft_unchanged() {
            backend.storedDrafts["chat-a"] = {text: "Szkic docelowy", revision: 1, attachments: []};
            show(); choose("selectMessage"); tryCompare(control("messageHistory"), "selectedIds", ["own"]);
            tryCompare(control("messageActionPopup"), "visible", false);
            const second = findChild(row(1), "messageSelection"); mouseClick(second, 10, 10);
            compare(control("messageHistory").selectedIds, ["own", "peer"]);
            choose("forwardSelection"); tryCompare(control("messageActionPopup"), "opened", true);
            choose("forwardDestination"); compare(backend.sentCount, 0);
            choose("confirmForward"); tryCompare(backend, "sentCount", 2);
            const call = backend.calls.filter(c => c.method === "message.forward")[0];
            compare(call.params.messages.map(m => m.messageId), ["own", "peer"]);
            compare(call.params.targetConversationId, "chat-a");
            compare(backend.storedDrafts["chat-a"].text, "Szkic docelowy");
            compare(control("messageHistory").selectedIds, []);
        }
        function test_delete_scopes_and_invalidation_on_route_lock_redaction() {
            show(); choose("deleteMessage");
            verify(control("deleteMessageEveryone") !== null); choose("deleteMessageLocal");
            tryCompare(adapter.messages, "count", 1);
            tryCompare(control("messageActionPopup"), "visible", false);
            show(); (view.item as MessagesView).readingEnabled = false;
            tryCompare(control("messageActionPopup"), "visible", false);
            (view.item as MessagesView).readingEnabled = true;
            show(); hub.openConversation(adapter.address("chat-a"));
            tryCompare(control("messageActionPopup"), "visible", false);
            hub.openConversation(adapter.address("chat-g")); tryVerify(() => !adapter.loading && adapter.draftReady);
            show(); backend.event("message.redacted", {accountId: backend.accountId, conversationId: "chat-g", messageId: "peer"});
            tryCompare(control("messageActionPopup"), "visible", false);
        }
    }
}
