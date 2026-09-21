import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"

Item {
    id: scene
    width: 1000; height: 700
    MockAudioBackend { id: backend }
    AudioService { id: audio; backend: backend; operationTimeout: 160 }
    QtObject {
        id: panelLoader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader {
            active: panelLoader.activeAsync
            asynchronous: true
            sourceComponent: preview.panelComponent
        }
    }
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: panelLoader; audio: audio }
    SignalSpy { id: feedback; target: audio; signalName: "feedback" }

    TestCase {
        name: "Audio"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            audio.pending = null;
            audio.lastError = "";
            audio.microphone.pending = null;
            audio.microphone.lastError = "";
            backend.reset();
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            preview.backend.reset();
            scene.width = 1000; scene.height = 700;
            preview.osd.timeout = 240;
            wait(30);
            preview.osd.hide();
            tryCompare(preview.osdHost, "loaded", false);
            feedback.clear();
            mouseMove(scene, 100, 600);
        }
        function cleanup() {
            preview.coordinator.close(false);
            preview.osd.hide();
            tryCompare(preview.panelHost, "loaded", false);
            tryCompare(preview.osdHost, "loaded", false);
        }
        function control(name) { return findChild(preview.panelHost.window, name); }
        function open() {
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("audioVolume") && control("audioVolume").activeFocus);
            verify(waitForPolish(scene));
            // Focus is assigned before FadeScope has presented its first frame.
            // A pointer click on an opacity-zero subtree is not delivered.
            tryCompare(preview.panelHost.window, "opacity", 1);
        }
        function test_no_startup_or_reconnect_osd() {
            compare(feedback.count, 0);
            verify(!preview.osd.visible);
            backend.ready = false;
            tryCompare(audio, "available", false);
            compare(audio.volume, -1);
            verify(!audio.setVolume(50, ""));
            backend.ready = true;
            tryCompare(audio, "available", true);
            wait(20);
            compare(feedback.count, 0);
            verify(!preview.osd.visible);
        }
        function test_invalid_values_data() {
            return [
                {tag: "negative", value: -1}, {tag: "over", value: 101},
                {tag: "nan", value: NaN}, {tag: "infinity", value: Infinity},
                {tag: "string", value: "50"}, {tag: "null", value: null}
            ];
        }
        function test_invalid_values(data) {
            verify(!audio.setVolume(data.value, ""));
            compare(audio.volume, 42);
            verify(audio.lastError.length > 0);
            verify(!audio.busy);
            compare(feedback.count, 0);
        }
        function test_invalid_delta_mute_and_stale_output() {
            for (const value of [NaN, Infinity, 101, -101, "5", null]) verify(!audio.changeVolume(value, ""));
            verify(!audio.setMuted(1, ""));
            verify(!audio.selectOutput({}, ""));
            compare(audio.volume, 42);
        }
        function test_slider_vim_arrows_mouse_mute_and_selection() {
            open();
            const slider = control("audioVolume");
            keyClick(Qt.Key_L);
            tryCompare(audio, "volume", 47);
            tryCompare(slider, "value", 47);
            keyClick(Qt.Key_H);
            tryCompare(audio, "volume", 42);
            keyClick(Qt.Key_Right);
            tryCompare(audio, "volume", 47);
            keyClick(Qt.Key_Left);
            tryCompare(audio, "volume", 42);
            mouseClick(slider, slider.width - slider.rightPadding, slider.height / 2);
            tryCompare(audio, "volume", 100);
            keyClick(Qt.Key_L);
            tryCompare(audio, "busy", false);
            compare(audio.volume, 100);
            verify(audio.setVolume(0, "TEST-1"));
            tryCompare(slider, "value", 0);
            keyClick(Qt.Key_H);
            tryCompare(audio, "busy", false);
            compare(audio.volume, 0);
            mouseClick(control("audioMute"));
            tryCompare(audio, "muted", true);
            mouseClick(control("audioMute"));
            tryCompare(audio, "muted", false);
            keyClick(Qt.Key_Space);
            tryCompare(audio, "muted", true);
            slider.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_J);
            verify(control("audioOutput-speakers").activeFocus);
            keyClick(Qt.Key_J);
            verify(control("audioOutput-headphones").activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(audio, "defaultOutput", backend.headphones);
            tryCompare(slider, "value", 65);
            compare(findChild(preview.bar, "barAudioValue"), null);
            verify(preview.bar.audioButton.Accessible.name.indexOf(audio.statusText) >= 0);
            verify(!preview.osd.visible);
            keyClick(Qt.Key_Escape);
            verify(control("audioVolume").activeFocus);
            compare(preview.coordinator.activeId, "quickSettings");
            keyClick(Qt.Key_Escape);
            compare(preview.coordinator.activeId, "");
        }
        function test_bar_wheel_and_navigation() {
            const barAudio = preview.bar.audioButton;
            mouseWheel(barAudio, 10, 10, 0, 120);
            tryCompare(audio, "volume", 47);
            tryCompare(preview.osdHost, "loaded", true);
            compare(preview.osd.screen, preview.firstScreen);
            preview.barController.focusBar();
            preview.bar.workspaces.selectIndex(preview.bar.workspaces.service.workspaces.count - 1, true);
            wait(10);
            keyClick(Qt.Key_L);
            verify(barAudio.activeFocus);
            keyClick(Qt.Key_L);
            verify(preview.bar.quickSettingsButton.activeFocus);
            keyClick(Qt.Key_H);
            verify(barAudio.activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(preview.panelHost, "loaded", true);
            compare(preview.coordinator.activeId, "audio");
            tryVerify(() => control("audioVolume").activeFocus);
            verify(!preview.osd.visible);
            keyClick(Qt.Key_Escape);
            tryVerify(() => barAudio.activeFocus);
        }
        function openAudio() {
            mouseClick(preview.bar.audioButton);
            tryCompare(preview.panelHost, "loaded", true);
            compare(preview.coordinator.activeId, "audio");
            tryVerify(() => control("audioVolume") && control("audioVolume").activeFocus);
        }
        function test_dedicated_panel_levels_devices_keyboard_and_mouse() {
            openAudio();
            compare(control("settingsButton"), null);
            verify(preview.bar.audioButton.highlighted);
            keyClick(Qt.Key_L);
            tryCompare(audio, "volume", 47);
            keyClick(Qt.Key_J);
            verify(control("microphoneVolume").activeFocus);
            keyClick(Qt.Key_L);
            tryCompare(audio.microphone, "volume", 47);
            compare(audio.volume, 47);
            keyClick(Qt.Key_Right);
            tryCompare(audio.microphone, "volume", 52);
            keyClick(Qt.Key_Backtab);
            verify(control("microphoneMute").activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(audio.microphone, "muted", true);
            verify(!audio.muted);
            keyClick(Qt.Key_L);
            keyClick(Qt.Key_J);
            verify(control("audioOutput-speakers").activeFocus);
            keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            tryCompare(audio, "defaultOutput", backend.headphones);
            keyClick(Qt.Key_J); keyClick(Qt.Key_J);
            verify(control("audioInput-usb-microphone").activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(audio.microphone, "defaultDevice", backend.input.headphones);
            verify(control("audioInput-usb-microphone").checked);
            compare(control("microphoneVolume").value, 65);
            verify(!preview.osd.visible);
            mouseClick(control("microphoneVolume"), 24, 18);
            tryCompare(audio.microphone, "busy", false);
            verify(audio.microphone.volume < 65);
            keyClick(Qt.Key_Escape);
            compare(preview.coordinator.activeId, "");
        }
        function test_microphone_confirmation_errors_and_independence() {
            const mic = audio.microphone;
            backend.input.delay = 65;
            for (let i = 0; i < 4; i++) verify(mic.changeVolume(5, "TEST-1"));
            compare(mic.volume, 42);
            verify(mic.busy);
            tryCompare(mic, "busy", false);
            compare(mic.volume, 62);
            compare(audio.volume, 42);
            compare(feedback.count, 0);
            verify(!preview.osd.visible);
            for (const value of [NaN, Infinity, -1, 101, "50", null]) verify(!mic.setVolume(value, ""));
            backend.input.dropWrites = true;
            verify(mic.selectDevice(backend.input.headphones, ""));
            compare(mic.defaultDevice, backend.input.speakers);
            tryCompare(mic, "busy", false);
            verify(mic.lastError.length > 0);
            compare(audio.lastError, "");
            backend.input.dropWrites = false;
            backend.input.rejectWrites = true;
            verify(!mic.setVolume(80, ""));
            compare(mic.volume, 62);
            backend.input.rejectWrites = false;
            verify(mic.setVolume(80, ""));
            backend.input.devices = [];
            backend.input.defaultDevice = null;
            tryCompare(mic, "busy", false);
            verify(!mic.available);
            verify(audio.available);
            verify(!mic.selectDevice(backend.input.headphones, ""));
        }
        function test_audio_panel_small_scroll_hotplug_and_unavailable_escape() {
            scene.width = 320; scene.height = 220;
            openAudio();
            control("audioInput-usb-microphone").forceActiveFocus();
            wait(20);
            const item = control("audioInput-usb-microphone");
            const position = item.mapToItem(preview.panelHost.window.viewport, 0, 0);
            verify(position.y >= 0 && position.y + item.height <= preview.panelHost.window.viewport.height);
            backend.input.devices = [backend.input.speakers];
            tryVerify(() => control("audioVolume").activeFocus);
            backend.ready = false;
            tryVerify(() => preview.panelHost.window.page.activeFocus);
            keyClick(Qt.Key_Escape);
            compare(preview.coordinator.activeId, "");
        }
        function test_audio_panel_monitor_exclusivity_and_lifecycle() {
            for (let i = 0; i < 20; i++) {
                verify(preview.coordinator.open("audio", preview.secondScreen, null));
                tryCompare(preview.panelHost, "loaded", true);
                compare(preview.panelHost.screen, preview.secondScreen);
                verify(preview.coordinator.open("quickSettings", preview.firstScreen, null));
                tryCompare(preview.panelHost, "loaded", true);
                tryVerify(() => control("settingsButton") !== null);
                verify(preview.coordinator.open("audio", preview.firstScreen, null));
                tryVerify(() => control("microphoneVolume") !== null);
                preview.coordinator.close(false);
                tryCompare(preview.panelHost, "loaded", false);
            }
            compare(preview.createdCount, preview.destroyedCount);
            verify(preview.coordinator.open("audio", preview.secondScreen, null));
            tryCompare(preview.panelHost, "loaded", true);
            preview.coordinator.screens = [preview.firstScreen];
            tryCompare(preview.panelHost, "loaded", false);
        }
        function test_external_update_shared_state_and_identity() {
            open();
            mouseClick(control("audioOutputs"));
            tryVerify(() => control("audioOutput-headphones") !== null);
            const device = control("audioOutput-headphones");
            device.forceActiveFocus();
            for (let i = 1; i <= 20; i++) backend.speakers.volume = i / 100;
            tryCompare(audio, "volume", 20);
            compare(control("audioVolume").value, 20);
            compare(findChild(preview.bar, "barAudioValue"), null);
            verify(preview.bar.audioButton.Accessible.name.indexOf(audio.statusText) >= 0);
            compare(control("audioOutput-headphones"), device);
            verify(device.activeFocus);
            verify(!preview.osd.visible);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            backend.speakers.volume = 1.35;
            tryCompare(preview.osdHost, "loaded", true);
            compare(audio.volume, 135);
            compare(findChild(preview.osdHost.window, "osdValue").text, "135%");
            compare(findChild(preview.bar, "barAudioValue"), null);
            verify(preview.bar.audioButton.Accessible.name.indexOf(audio.statusText) >= 0);
        }
        function test_burst_delay_rejection_and_timeout() {
            backend.delay = 65;
            for (let i = 0; i < 6; i++) verify(audio.changeVolume(5, "TEST-2"));
            verify(audio.toggleMute("TEST-2"));
            verify(audio.busy);
            compare(audio.volume, 42);
            compare(feedback.count, 0);
            tryCompare(audio, "busy", false);
            compare(audio.volume, 72);
            verify(audio.muted);
            compare(feedback.count, 1);
            compare(preview.osd.screen, preview.secondScreen);
            backend.rejectWrites = true;
            verify(!audio.setVolume(90, ""));
            compare(audio.volume, 72);
            verify(audio.lastError.length > 0);
            backend.rejectWrites = false;
            backend.dropWrites = true;
            verify(audio.setVolume(90, ""));
            tryCompare(audio, "busy", false);
            verify(audio.lastError.length > 0);
            compare(audio.volume, 72);
            backend.dropWrites = false;
            verify(audio.setVolume(55, ""));
            tryCompare(audio, "busy", false);
            compare(audio.volume, 55);
            compare(audio.lastError, "");
        }
        function test_slider_arrow_burst_with_delayed_backend_and_failed_write() {
            open();
            backend.delay = 65;
            for (let i = 0; i < 5; i++) keyClick(Qt.Key_Right);
            compare(audio.volume, 42);
            tryCompare(audio, "busy", false);
            compare(audio.volume, 67);
            compare(control("audioVolume").value, 67);
            backend.dropWrites = true;
            keyClick(Qt.Key_Right);
            tryCompare(audio, "busy", false);
            compare(audio.volume, 67);
            compare(control("audioVolume").value, 67);
            compare(control("audioError"), null);
            verify(audio.lastError.length > 0);
            backend.ready = false;
            tryVerify(() => control("settingsButton").activeFocus);
            backend.ready = true;
            control("audioVolume").forceActiveFocus();
            control("settingsButton").forceActiveFocus();
            backend.ready = false;
            wait(20);
            verify(control("settingsButton").activeFocus);
        }
        function test_output_preference_is_not_actual_and_removal() {
            backend.dropWrites = true;
            verify(audio.selectOutput(backend.headphones, ""));
            compare(audio.defaultOutput, backend.speakers);
            tryCompare(audio, "busy", false);
            verify(audio.lastError.length > 0);
            backend.dropWrites = false;
            backend.defaultOutput = null;
            tryCompare(audio, "available", false);
            compare(audio.volume, -1);
            backend.defaultOutput = backend.headphones;
            tryCompare(audio, "available", true);
            wait(20);
            verify(!preview.osd.visible);
            backend.delay = 100;
            verify(audio.setVolume(40, ""));
            backend.outputs = [backend.speakers];
            backend.defaultOutput = backend.speakers;
            tryCompare(audio, "busy", false);
            verify(audio.lastError.length > 0);
            compare(audio.volume, 42);
        }
        function test_timeout_renewal_monitor_removal_theme_and_focus() {
            preview.bar.quickSettingsButton.forceActiveFocus();
            backend.speakers.volume = 0.5;
            tryCompare(preview.osdHost, "loaded", true);
            const window = preview.osdHost.window;
            verify(preview.bar.quickSettingsButton.activeFocus);
            wait(130);
            backend.speakers.volume = 0.55;
            wait(130);
            verify(preview.osd.visible);
            compare(preview.osdHost.window, window);
            preview.settings.beginEdit();
            preview.settings.setColor("accent", "#94e2d5");
            compare(findChild(window, "osdFill").color, Theme.accent);
            preview.settings.cancelEdit();
            tryCompare(preview.osdHost, "loaded", false);
            compare(preview.osdCreated, preview.osdDestroyed);
            audio.changeVolume(5, "TEST-2");
            tryCompare(preview.osdHost, "loaded", true);
            compare(preview.osd.screen, preview.secondScreen);
            preview.coordinator.screens = [preview.firstScreen];
            tryCompare(preview.osdHost, "loaded", false);
            preview.backend.focusedMonitorName = "missing";
            audio.changeVolume(5, "");
            tryCompare(preview.osdHost, "loaded", true);
            compare(preview.osd.screen, preview.firstScreen);
            backend.ready = false;
            tryCompare(preview.osdHost, "loaded", false);
        }
        function test_small_panel_keyboard_reveals_controls_and_skips_missing() {
            scene.width = 320; scene.height = 220;
            open();
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_J); keyClick(Qt.Key_J);
            verify(control("audioOutput-headphones").activeFocus);
            const position = control("audioOutput-headphones").mapToItem(preview.panelHost.window.viewport, 0, 0);
            verify(position.y >= 0 && position.y + control("audioOutput-headphones").height <= preview.panelHost.window.viewport.height);
            compare(preview.panelHost.window.width, 304);
            backend.outputs = [];
            backend.defaultOutput = null;
            tryVerify(() => control("settingsButton").activeFocus);
            keyClick(Qt.Key_Tab);
            verify(control("settingsButton").activeFocus, "Focus: " + scene.Window.window.activeFocusItem.objectName);
        }
    }
}
