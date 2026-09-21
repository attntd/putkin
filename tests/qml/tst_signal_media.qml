pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import QtMultimedia
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
    Loader { id: view; active: false; anchors.fill: parent; sourceComponent: MessagesView { hub: hub } }
    TestCase {
        name: "SignalMedia"
        when: windowShown
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            view.active = false; backend.seed(); adapter.clear(); view.active = true;
            tryCompare(adapter, "listLoading", false);
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && !adapter.loading);
            wait(80);
        }
        function cleanup() { backend.release(); settings.cancelEdit(); wait(300); view.active = false; wait(250); }
        function control(name) { return findChild(view.item, name); }
        function test_attachment_only_remove_restart_and_keyboard_paste() {
            verify(adapter.attachFiles(["file:///synthetic/a.png", "file:///synthetic/b.png"]));
            tryCompare(adapter, "mediaBusy", 0);
            compare(adapter.draftAttachments.length, 2);
            const remove = control("removeAttachment");
            remove.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryVerify(() => adapter.draftAttachments.length === 1);
            wait(100);
            adapter.clear(); hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && !adapter.loading);
            compare(adapter.draftAttachments.length, 1);
            const editor = control("messageEditor"); editor.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_V, Qt.ControlModifier | Qt.ShiftModifier);
            tryVerify(() => adapter.draftAttachments.length === 2);
            compare(backend.calls.filter(c => c.method === "attachment.paste").length, 1);
            keyClick(Qt.Key_Return);
            tryCompare(backend, "sentCount", 1);
            compare(backend.calls.filter(c => c.method === "message.send")[0].params.attachmentIds.length, 2);
            tryVerify(() => adapter.draftAttachments.length === 0);
        }
        function test_preparation_blocks_send_and_stale_selection_does_not_mix_files() {
            backend.holdResponses = true;
            adapter.attachFiles(["file:///synthetic/a.png"]);
            verify(!adapter.send()); compare(adapter.mediaBusy, 1);
            hub.openConversation(adapter.address("chat-a")); backend.release();
            tryVerify(() => adapter.draftReady && adapter.selectedRoute.conversationId === "chat-a");
            compare(adapter.draftAttachments.length, 0);
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && adapter.selectedRoute.conversationId === "chat-g");
            compare(adapter.draftAttachments.length, 1);
        }
        function preview(kind, fileName) {
            const url = Qt.resolvedUrl("../fixtures/signal/media/" + fileName).toString();
            (view.item as MessagesView).previewAttachment = {attachment_id: "fixture", filename: fileName, content_type: kind,
                size_bytes: 2048, url: url, preview: kind.indexOf("image/") === 0 ? url : ""};
            tryVerify(() => control("mediaPreview") !== null);
            wait(250);
            return control("mediaPreview");
        }
        function test_thumbnail_click_and_keyboard_open_preview_and_restore_focus_data() {
            return [{tag: "image", filename: "image.png", mime: "image/png", image: true},
                {tag: "document", filename: "document.txt", mime: "text/plain", image: false}];
        }
        function test_thumbnail_click_and_keyboard_open_preview_and_restore_focus(data) {
            const url = data.image ? Qt.resolvedUrl("../fixtures/signal/media/image.png").toString() : "";
            view.active = false;
            backend.history["chat-g"] = [Object.assign(backend.message("chat-g", "photo", 0), {
                attachments: [{attachment_id: "photo", filename: data.filename, size_bytes: 2048,
                    content_type: data.mime, thumbnail: url, preview: url, url: url, state: "ready", errorCode: ""}]
            })];
            adapter.clear(); view.active = true;
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && !adapter.loading && control("previewAttachment") !== null);
            const thumbnail = control("previewAttachment");
            waitForRendering(thumbnail);
            mouseClick(thumbnail, thumbnail.width / 2, thumbnail.height / 2);
            tryVerify(() => control("mediaPreview") !== null && control("closeMediaPreview").activeFocus);
            compare(control("attachmentFilename").text, data.filename);
            compare(control("attachmentSize").text, "2.0 KiB");
            verify(control("saveMedia").visible && control("openMedia").visible);
            control("openMedia").click();
            const open = backend.calls.filter(c => c.method === "attachment.open");
            compare(open.length, 1); compare(open[0].params.attachmentId, "photo");
            wait(250); keyClick(Qt.Key_Escape);
            tryVerify(() => !(view.item as MessagesView).previewAttachment);
            verify(thumbnail.activeFocus);
            thumbnail.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryVerify(() => control("closeMediaPreview") !== null && control("closeMediaPreview").activeFocus);
            compare(control("closeMediaPreview").focusReason, Qt.TabFocusReason);
            wait(250); control("closeMediaPreview").click();
            tryVerify(() => !(view.item as MessagesView).previewAttachment);
            verify(thumbnail.activeFocus);
        }
        function test_image_preview_focus_escape_and_live_preview_save_cancel() {
            (view.item as MessagesView).previewReason = Qt.MouseFocusReason;
            const surface = preview("image/png", "image.png");
            verify(control("closeMediaPreview").activeFocus);
            compare(control("closeMediaPreview").focusReason, Qt.MouseFocusReason);
            keyClick(Qt.Key_Tab); verify(control("saveMedia").activeFocus);
            keyClick(Qt.Key_Tab); verify(control("openMedia").activeFocus);
            keyClick(Qt.Key_Tab); verify(control("closeMediaPreview").activeFocus);
            keyClick(Qt.Key_Backtab); verify(control("openMedia").activeFocus);
            keyClick(Qt.Key_Tab); verify(control("closeMediaPreview").activeFocus);
            settings.beginEdit(); waitForRendering(surface); const original = grabImage(surface);
            settings.setColor("accent", "#89b4fa"); settings.setColor("accentSecondary", "#f38ba8");
            waitForRendering(surface); const changed = grabImage(surface); verify(!original.equals(changed));
            settings.cancelEdit(); waitForRendering(surface); verify(original.equals(grabImage(surface)));
            settings.beginEdit(); settings.setColor("accent", "#89b4fa"); settings.setColor("accentSecondary", "#f38ba8");
            verify(settings.save()); tryCompare(settings, "saving", false); settings.cancelEdit();
            waitForRendering(surface); verify(changed.equals(grabImage(surface)));
            keyClick(Qt.Key_Escape);
            tryVerify(() => !(view.item as MessagesView).previewAttachment);
            verify(control("messageEditor").activeFocus);
        }
        function test_qt_video_decoder_play_pause_and_audio_metadata() {
            preview("video/mp4", "video.mp4");
            let player = control("attachmentPlayer");
            tryVerify(() => player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia);
            compare(player.error, MediaPlayer.NoError);
            verify(player.duration > 0);
            control("playMedia").click();
            tryVerify(() => player.position > 0);
            keyClick(Qt.Key_Escape); tryVerify(() => !(view.item as MessagesView).previewAttachment);
            preview("audio/x-wav", "audio.wav"); player = control("attachmentPlayer");
            tryVerify(() => player.duration > 0);
            compare(player.error, MediaPlayer.NoError);
        }
    }
}
