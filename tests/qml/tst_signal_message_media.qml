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
    Loader { id: view; active: false; anchors.fill: parent; sourceComponent: MessagesView { hub: hub; readingEnabled: true } }
    TestCase {
        name: "SignalMessageMedia"
        when: windowShown
        function control(name) { return findChild(view.item, name); }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            view.active = false; scene.width = 980; backend.seed(); adapter.clear();
        }
        function cleanup() { backend.release(); view.active = false; settings.cancelEdit(); wait(200); }
        function attachment(name = "image.png", mime = "image/png", id = "media-1") {
            const url = Qt.resolvedUrl("../fixtures/signal/media/" + name).toString();
            const thumb = /^(image|video)\//.test(mime) ? Qt.resolvedUrl("../fixtures/signal/media/image.png").toString() : "";
            return {attachment_id: id, filename: name, size_bytes: 2048, state: "ready", errorCode: "", content_type: mime,
                thumbnail: thumb, preview: /^image\//.test(mime) ? url : "", url: url, voiceNote: false};
        }
        function openMedia(attachments, text = null, outgoing = false) {
            backend.history["chat-a"] = [Object.assign(backend.message("chat-a", "media", 0), {
                text: text, kind: "media", direction: outgoing ? "outgoing" : "incoming", status: outgoing ? "sent" : "received",
                attachments: attachments, canReact: true, canReply: true, canDeleteLocal: true, unread: false
            })];
            view.active = true;
            tryCompare(adapter, "listLoading", false);
            hub.openConversation(adapter.address("chat-a"));
            tryVerify(() => adapter.draftReady && !adapter.loading && control("messageHistory").count === 1);
            const history = control("messageHistory"); history.forceLayout();
            tryVerify(() => history.itemAtIndex(0) !== null);
            wait(100);
            return history.itemAtIndex(0);
        }
        function save(name) {
            mouseMove(scene, scene.width - 2, 2);
            waitForRendering(view.item);
            grabImage(view.item).save(Qt.resolvedUrl("../../docs/evidence/signal-message-polish-20260926/" + name + ".png").toString().replace("file://", ""));
        }
        function savePreview(name) {
            if (Screen.devicePixelRatio !== 1) return;
            let captured = false;
            (view.item as MessagesView).grabToImage(result => {
                result.saveToFile(Qt.resolvedUrl("../../artifacts/signal-gui-20261003/" + name + ".png").toString().replace("file://", ""));
                captured = true;
            });
            tryVerify(() => captured);
        }
        function test_photo_is_edge_to_edge_without_placeholder_data() {
            return [{tag: "wide-incoming", width: 980, outgoing: false}, {tag: "narrow-outgoing", width: 320, outgoing: true}];
        }
        function test_photo_is_edge_to_edge_without_placeholder(data) {
            scene.width = data.width;
            const item = openMedia([attachment()], null, data.outgoing);
            const thumb = control("attachmentThumbnail"), preview = control("previewAttachment");
            tryCompare(thumb, "status", Image.Ready);
            compare(adapter.messages.get(0).text, "");
            verify(!control("messageBody").visible);
            verify(!control("attachmentCardFilename").visible);
            verify(!control("attachmentAvailability").visible);
            const offset = preview.mapToItem(item.bubble, 0, 0);
            compare(offset.x, 0); compare(offset.y, 0);
            compare(preview.width, item.bubble.width);
            compare(preview.height, item.bubble.height);
            verify(Math.abs(preview.height / preview.width - 64 / 96) < .01, "single image preserves its aspect ratio");
            const action = findChild(item, "reactMessage"), center = action.mapToItem(item.bubble, 0, action.height / 2);
            verify(Math.abs(center.y - item.bubble.height / 2) < 1);
            save("photo-" + data.tag);
            mouseClick(preview, preview.width / 2, preview.height / 2);
            tryVerify(() => control("closeMediaPreview") !== null && control("closeMediaPreview").activeFocus);
            keyClick(Qt.Key_Escape);
            tryVerify(() => !(view.item as MessagesView).previewAttachment);
            verify(preview.activeFocus);
        }
        function test_caption_keeps_literal_attachment_word_below_photo() {
            openMedia([attachment()], "Załącznik z wakacji 🐈");
            tryCompare(control("attachmentThumbnail"), "status", Image.Ready);
            const body = control("messageBody"), gallery = control("messageAttachments");
            verify(body.visible);
            compare(adapter.messages.get(0).text, "Załącznik z wakacji 🐈");
            verify(body.y >= gallery.y + gallery.height);
            save("photo-caption");
        }
        function test_original_pixels_and_resolution_in_bubble_and_preview() {
            const original = attachment("detail.png");
            // Deliberately different low-resolution derivatives: decoding one
            // of them must fail both the pixel and effective resolution checks.
            original.preview = original.thumbnail;
            openMedia([original]);
            const thumb = control("attachmentThumbnail");
            tryCompare(thumb, "status", Image.Ready);
            verify(thumb.implicitWidth >= thumb.width * Screen.devicePixelRatio - 2);
            waitForRendering(thumb);
            let pixels = grabImage(view.item);
            const sample = thumb.mapToItem(view.item, thumb.width / 4, thumb.height / 2);
            compare(pixels.pixel(Math.floor(sample.x * Screen.devicePixelRatio), Math.floor(sample.y * Screen.devicePixelRatio)),
                Qt.rgba(32 / 255, 224 / 255, 64 / 255, 1));
            const trigger = control("previewAttachment");
            mouseClick(trigger, trigger.width / 2, trigger.height / 2);
            tryVerify(() => control("attachmentImage") !== null);
            const image = control("attachmentImage"), surface = control("mediaPreview");
            tryCompare(image, "status", Image.Ready);
            tryCompare(surface, "opacity", 1);
            compare(image.width, surface.width); compare(image.height, surface.height);
            verify(image.implicitWidth >= image.paintedWidth * Screen.devicePixelRatio - 2);
            verify(image.implicitHeight >= image.paintedHeight * Screen.devicePixelRatio - 2);
            waitForRendering(image);
            pixels = grabImage(image);
            compare(pixels.pixel(Math.floor(pixels.width / 4), Math.floor(pixels.height / 2)), Qt.rgba(32 / 255, 224 / 255, 64 / 255, 1));
            verify(!control("openMedia").visible);
        }
        function test_photo_overlays_hover_keyboard_and_pointer_focus() {
            openMedia([attachment("detail.png")]);
            const trigger = control("previewAttachment");
            mouseClick(trigger, trigger.width / 2, trigger.height / 2);
            tryVerify(() => control("mediaPreview") !== null);
            const surface = control("mediaPreview"), overlay = control("mediaOverlay"), image = control("attachmentImage");
            tryCompare(image, "status", Image.Ready);
            tryCompare(surface, "opacity", 1);
            mouseMove(scene, -20, -20);
            tryCompare(overlay, "opacity", 0);
            waitForRendering(view.item);
            savePreview("image-clean");
            verify(!findChild(control("closeMediaPreview"), "focusIndicator").visible);
            mouseMove(surface, surface.width / 2, surface.height / 2);
            tryCompare(overlay, "opacity", 1);
            waitForRendering(view.item);
            savePreview("image-hover");
            const filename = control("attachmentFilename"), close = control("closeMediaPreview"), saveButton = control("saveMedia");
            const top = filename.mapToItem(image, 0, 0), bottom = close.mapToItem(image, 0, close.height);
            verify(top.y >= (image.height - image.paintedHeight) / 2);
            verify(bottom.y <= (image.height + image.paintedHeight) / 2);
            verify(top.y < image.height / 2 && bottom.y > image.height / 2);
            mouseMove(scene, -20, -20); tryCompare(overlay, "opacity", 0);
            keyClick(Qt.Key_Tab);
            verify(saveButton.activeFocus); tryCompare(overlay, "opacity", 1);
            keyClick(Qt.Key_L); verify(close.activeFocus);
            keyClick(Qt.Key_H); verify(saveButton.activeFocus);
            mouseClick(surface, surface.width / 2, surface.height / 2);
            verify(!findChild(saveButton, "focusIndicator").visible);
            mouseMove(scene, -20, -20); tryCompare(overlay, "opacity", 0);
            mouseMove(close, close.width / 2, close.height / 2);
            tryCompare(overlay, "opacity", 1);
            mouseClick(close, close.width / 2, close.height / 2);
            tryVerify(() => !(view.item as MessagesView).previewAttachment);
        }
        function test_rejected_image_never_decodes_original() {
            const rejected = attachment("detail.png");
            rejected.errorCode = "media_dimensions";
            rejected.thumbnail = ""; rejected.preview = "";
            openMedia([rejected]);
            compare(control("attachmentThumbnail").status, Image.Null);
            const trigger = control("previewAttachment");
            mouseClick(trigger, trigger.width / 2, trigger.height / 2);
            tryVerify(() => control("mediaPreview") !== null);
            compare(control("attachmentImage").status, Image.Null);
            verify(control("mediaPreview").decoderFailed);
        }
        function test_photo_mosaic_keeps_all_files_clickable_data() {
            return [2, 3, 4, 5, 7].map(count => ({tag: String(count), count: count}));
        }
        function test_photo_mosaic_keeps_all_files_clickable(data) {
            const files = Array.from({length: data.count}, (_, i) => attachment("image.png", "image/png", "photo-" + i));
            const item = openMedia(files);
            const gallery = control("messageAttachments");
            tryVerify(() => gallery.height > 0);
            const cards = gallery.children.filter(child => child.attachment !== undefined);
            compare(cards.length, data.count);
            for (let i = 0; i < cards.length; i++) {
                const a = cards[i];
                tryCompare(findChild(a, "attachmentThumbnail"), "status", Image.Ready);
                verify(a.x >= 0 && a.x + a.width <= gallery.width + 1);
                verify(a.y >= 0 && a.y + a.height <= gallery.height + 1);
                for (let j = i + 1; j < cards.length; j++) {
                    const b = cards[j];
                    verify(a.x + a.width <= b.x + .5 || b.x + b.width <= a.x + .5 || a.y + a.height <= b.y + .5 || b.y + b.height <= a.y + .5, "photos do not overlap");
                }
            }
            save("photos-" + data.count);
            const last = findChild(cards[cards.length - 1], "previewAttachment");
            last.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryVerify(() => control("mediaPreview") !== null);
            compare((view.item as MessagesView).previewAttachment.attachment_id, "photo-" + (data.count - 1));
            keyClick(Qt.Key_Escape);
            tryVerify(() => !(view.item as MessagesView).previewAttachment);
            compare(item.bubble.height, gallery.height);
        }
        function test_file_card_name_size_and_unavailable_state() {
            const file = attachment("document.txt", "text/plain");
            file.filename = "Raport <Q3> & wyniki.txt";
            openMedia([file]);
            compare(control("attachmentCardFilename").text, file.filename);
            compare(control("attachmentCardFilename").textFormat, Text.PlainText);
            compare(control("attachmentCardSize").text, "2.0 kB");
            verify(!control("messageBody").visible);
            save("document");
            const preview = control("previewAttachment");
            mouseClick(preview, preview.width / 2, preview.height / 2);
            tryVerify(() => control("attachmentFilename") !== null);
            compare(control("attachmentFilename").text, file.filename);
            tryVerify(() => control("closeMediaPreview").activeFocus && control("mediaPreview").opacity === 1);
            keyClick(Qt.Key_Escape); tryVerify(() => !(view.item as MessagesView).previewAttachment);
            file.state = "unavailable"; file.url = "";
            adapter.merge(backend.history["chat-a"], false);
            tryVerify(() => !control("previewAttachment").enabled && control("attachmentAvailability").visible);
            verify(!control("messageBody").visible);
        }
        function test_video_thumbnail_has_play_and_opens_player() {
            openMedia([attachment("video.mp4", "video/mp4")]);
            tryCompare(control("attachmentThumbnail"), "status", Image.Ready);
            verify(control("videoPlayBadge").visible);
            verify(!control("attachmentCardFilename").visible);
            save("video");
            const preview = control("previewAttachment");
            preview.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryVerify(() => control("attachmentPlayer") !== null);
            tryVerify(() => control("attachmentPlayer").duration > 0);
            verify(control("playMedia").visible);
        }
        function test_pending_photo_keeps_state_visible_and_never_overlaps() {
            const pending = attachment("image.png", "image/png", "pending");
            pending.state = "pending"; pending.thumbnail = ""; pending.preview = ""; pending.url = "";
            const item = openMedia([pending, attachment()]);
            const gallery = control("messageAttachments"), cards = gallery.children.filter(child => child.attachment !== undefined);
            tryVerify(() => gallery.height > 0);
            verify(findChild(cards[0], "attachmentAvailability").visible);
            verify(!findChild(cards[0], "previewAttachment").enabled);
            verify(cards[1].y >= cards[0].y + cards[0].height);
            verify(item.bubble.height > gallery.height, "metadata leaves room for attachment state");
        }
        function test_audio_inline_play_pause_seek_and_stop_on_lock() {
            openMedia([attachment("audio-long.wav", "audio/wav")]);
            const audio = control("audioAttachment"), play = control("playAudioAttachment");
            // Actual decoder/clock, explicitly no audio output or host device.
            audio.soundFactory = null;
            compare(audio.mediaPlayer.playbackState, MediaPlayer.StoppedState);
            verify(!control("messageBody").visible);
            save("audio");
            play.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryVerify(() => audio.mediaPlayer.position > 0);
            compare(audio.mediaPlayer.audioOutput, null);
            keyClick(Qt.Key_Return);
            tryCompare(audio.mediaPlayer, "playbackState", MediaPlayer.PausedState);
            const seek = control("audioSeek"); verify(seek.enabled);
            seek.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_L);
            verify(audio.mediaPlayer.position >= 5000);
            keyClick(Qt.Key_H); verify(audio.mediaPlayer.position < 5000);
            keyClick(Qt.Key_Return);
            tryCompare(audio.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
            (view.item as MessagesView).readingEnabled = false;
            tryCompare(audio.mediaPlayer, "playbackState", MediaPlayer.StoppedState);
            verify(!play.enabled);
        }
        function test_mixed_media_and_exclusive_audio_playback() {
            const voice = attachment("audio-long.wav", "audio/wav", "voice"); voice.voiceNote = true;
            openMedia([attachment(), attachment("audio-long.wav", "audio/wav", "audio"), voice]);
            const gallery = control("messageAttachments"), cards = gallery.children.filter(child => child.attachment !== undefined);
            tryVerify(() => cards.length === 3 && gallery.height > 0);
            const first = findChild(cards[1], "audioAttachment"), second = findChild(cards[2], "audioAttachment");
            first.soundFactory = null; second.soundFactory = null;
            verify(!findChild(second, "audioFilename").visible);
            verify(cards[1].y >= cards[0].y + cards[0].height);
            verify(cards[2].y >= cards[1].y + cards[1].height);
            save("mixed-attachments");
            findChild(first, "playAudioAttachment").click();
            tryCompare(first.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
            findChild(second, "playAudioAttachment").click();
            tryCompare(second.mediaPlayer, "playbackState", MediaPlayer.PlayingState);
            compare(first.mediaPlayer.playbackState, MediaPlayer.StoppedState);
            (view.item as MessagesView).visible = false;
            tryCompare(second.mediaPlayer, "playbackState", MediaPlayer.StoppedState);
        }
    }
}
