import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"

Item {
    id: scene
    width: 1000; height: 760
    MockBrightnessBackend { id: backend }
    BrightnessService { id: brightness; backend: backend }
    readonly property alias brightnessModel: brightness
    MockAudioBackend { id: audioBackend }
    AudioService { id: audio; backend: audioBackend }
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
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: panelLoader; audio: audio; brightness: scene.brightnessModel }
    SignalSpy { id: feedback; target: brightness; signalName: "feedback" }

    TestCase {
        name: "Brightness"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            tryCompare(brightness, "busy", false);
            backend.reset();
            audioBackend.reset();
            brightness.refresh();
            tryCompare(brightness, "busy", false);
            compare(brightness.percent, 60);
            preview.backend.reset();
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            scene.width = 1000; scene.height = 760;
            preview.osd.timeout = 500;
            wait(30);
            preview.osd.hide();
            tryCompare(preview.osdHost, "loaded", false);
            feedback.clear();
            mouseMove(scene, 100, 720);
        }
        function cleanup() {
            backend.automatic = true;
            // Finish a deliberately held request even after a failed assertion.
            if (brightness.active) backend.deliver(backend.requests[backend.requests.length - 1]);
            tryCompare(brightness, "busy", false);
            preview.coordinator.close(false);
            preview.osd.hide();
            tryCompare(preview.panelHost, "loaded", false);
            tryCompare(preview.osdHost, "loaded", false);
        }
        function control(name) { return findChild(preview.panelHost.window, name); }
        function open() {
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryCompare(brightness, "busy", false);
            tryVerify(() => control("audioVolume") && control("audioVolume").activeFocus);
        }
        function writes() { return backend.requests.filter(request => request.arguments.indexOf("set") >= 0); }
        function settle(value) {
            tryCompare(brightness, "busy", false);
            compare(brightness.percent, value);
        }
        function test_invalid_input_data() {
            return [{tag: "zero", value: 0}, {tag: "negative", value: -1}, {tag: "over", value: 101},
                {tag: "nan", value: NaN}, {tag: "infinity", value: Infinity}, {tag: "string", value: "50"}, {tag: "null", value: null}];
        }
        function test_invalid_input(data) {
            verify(!brightness.setPercent(data.value, ""));
            compare(writes().length, 0);
            compare(brightness.percent, 60);
            verify(brightness.lastError.length > 0);
            compare(feedback.count, 0);
        }
        function test_invalid_delta() {
            for (const value of [NaN, Infinity, -101, 101, "5", null]) verify(!brightness.change(value, ""));
            compare(writes().length, 0);
        }
        function test_zero_observed_and_small_range_never_write_zero() {
            backend.devices = [{device: "small", current: 0, maximum: 7}];
            brightness.refresh();
            settle(0);
            verify(brightness.available);
            open();
            compare(control("brightnessStatus").text, "0%");
            compare(control("brightnessSlider").value, 1);
            compare(writes().length, 0);
            verify(brightness.setPercent(1, ""));
            settle(100 / 7);
            compare(writes()[0].arguments.slice(-1)[0], "1");
            verify(brightness.change(5, ""));
            settle(200 / 7);
            verify(brightness.change(-5, ""));
            settle(100 / 7);
            control("brightnessSlider").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right); settle(200 / 7);
            keyClick(Qt.Key_Left); settle(100 / 7);
            verify(brightness.setPercent(100, ""));
            settle(100);
            verify(brightness.change(5, ""));
            settle(100);
            verify(brightness.change(-100, ""));
            settle(100 / 7);
        }
        function test_unavailable_or_invalid_range_data() {
            return [{tag: "absent", devices: []}, {tag: "zero-max", devices: [{device: "bad", current: 0, maximum: 0}]},
                {tag: "unknown-max", devices: [{device: "bad", current: 3}]},
                {tag: "outside-range", devices: [{device: "bad", current: 101, maximum: 100}]},
                {tag: "wildcard-name", devices: [{device: "bad*", current: 30, maximum: 100}]}];
        }
        function test_unavailable_or_invalid_range(data) {
            backend.devices = data.devices;
            brightness.refresh();
            tryCompare(brightness, "busy", false);
            verify(!brightness.available);
            compare(brightness.percent, -1);
            verify(!brightness.setPercent(50, ""));
            open();
            verify(!control("brightnessSlider").enabled);
            control("audioVolume").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_J);
            verify(control("brightnessDetails").activeFocus);
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_J);
            verify(control("brightnessRefresh").activeFocus);
            backend.devices = [{device: "back", current: 35, maximum: 100}];
            keyClick(Qt.Key_Return);
            settle(35);
            verify(control("brightnessSlider").visible);
            verify(control("brightnessRefresh").activeFocus);
        }
        function test_selection_stable_and_device_disappears() {
            backend.devices = [{device: "acpi_video0", current: 6, maximum: 10},
                {device: "native", current: 250, maximum: 1000}, {device: "z_native", current: 90, maximum: 1000}];
            brightness.refresh(); settle(25);
            compare(brightness.device, "native");
            backend.devices = backend.devices.slice().reverse().concat([{device: "new", current: 500, maximum: 2000}]);
            brightness.refresh(); settle(25);
            compare(brightness.device, "native");
            verify(brightness.setPercent(50, "")); settle(50);
            compare(writes().slice(-1)[0].arguments[1], "--device=native");
            backend.devices = [{device: "acpi_video0", current: 6, maximum: 10}];
            brightness.refresh(); settle(60);
            compare(brightness.device, "acpi_video0");
        }
        function test_permission_error_and_unconfirmed_write_no_success() {
            open();
            backend.writeError = "Permission denied";
            verify(brightness.setPercent(85, "TEST-1")); settle(60);
            verify(brightness.lastError.indexOf("Permission denied") >= 0);
            compare(control("brightnessSlider").value, 60);
            compare(control("brightnessStatus").text, "60%");
            compare(feedback.count, 0);
            verify(!preview.osd.visible);
            backend.writeError = ""; backend.ignoreWrites = true;
            verify(brightness.setPercent(85, "TEST-1")); settle(60);
            verify(brightness.lastError.indexOf("nie potwierdził") >= 0);
            compare(feedback.count, 0);
            backend.ignoreWrites = false;
            verify(brightness.setPercent(85, "TEST-1")); settle(85);
            compare(brightness.lastError, "");
            verify(brightness.diagnostic.indexOf("Urządzenie:") === 0);
        }
        function test_read_error_is_diagnostic_not_zero() {
            backend.readError = "Permission denied";
            brightness.refresh();
            tryCompare(brightness, "busy", false);
            verify(!brightness.available);
            compare(brightness.percent, -1);
            verify(brightness.diagnostic.indexOf("Permission denied") >= 0);
            compare(feedback.count, 0);
        }
        function test_coalescing_and_late_replies() {
            backend.automatic = false;
            let count = backend.requests.length;
            verify(brightness.setPercent(20, "TEST-1"));
            tryVerify(() => backend.requests.length > count);
            const first = backend.requests[count];
            for (let i = 21; i <= 90; i++) verify(brightness.setPercent(i, "TEST-2"));
            compare(brightness.percent, 60);
            compare(brightness.requestedPercent, 90);
            backend.deliver(first);
            tryVerify(() => backend.requests.length === count + 2);
            const second = backend.requests[count + 1];
            compare(second.arguments.slice(-1)[0], "90");
            backend.deliver(second);
            tryVerify(() => backend.requests.length === count + 3);
            const read = backend.requests[count + 2];
            // An old completion arriving during the current read is ignored.
            backend.completed(first.id, {code: 1, failure: "timeout", error: "late", output: ""});
            compare(brightness.requestedPercent, 90);
            compare(brightness.lastError, "");
            backend.deliver(read);
            settle(90);
            compare(feedback.count, 1);
            compare(feedback.signalArguments[0][0], "TEST-2");
            // Deliver older replies in reverse order after the newest success.
            backend.completed(second.id, {code: 1, failure: "", error: "old", output: ""});
            backend.completed(first.id, {code: 0, failure: "", error: "", output: "test_backlight,backlight,20,20%,100"});
            compare(brightness.percent, 90);
            compare(brightness.lastError, "");
            compare(writes().length, 2);
            backend.automatic = true;
        }
        function test_refresh_reply_cannot_overwrite_new_intent() {
            backend.automatic = false;
            const count = backend.requests.length;
            brightness.refresh();
            tryVerify(() => backend.requests.length === count + 1);
            const oldRead = backend.requests[count];
            verify(brightness.setPercent(75, ""));
            backend.completed(oldRead.id, {code: 0, failure: "", error: "", output: "test_backlight,backlight,15,15%,100"});
            compare(brightness.percent, 60);
            tryVerify(() => backend.requests.length === count + 2);
            backend.automatic = true;
            backend.deliver(backend.requests[count + 1]);
            settle(75);
        }
        function test_timeout_result_retains_confirmed_level() {
            backend.automatic = false;
            const count = backend.requests.length;
            verify(brightness.setPercent(90, ""));
            tryVerify(() => backend.requests.length > count);
            backend.automatic = true;
            backend.completed(backend.requests[count].id, {code: 9, failure: "timeout", error: "", output: ""});
            settle(60);
            verify(brightness.lastError.indexOf("czas") >= 0);
            compare(feedback.count, 0);
        }
        function test_panel_reopen_refresh_and_no_idle_poll() {
            open();
            const reads = backend.requests.length;
            backend.devices = [{device: "test_backlight", current: 27, maximum: 100}];
            wait(180);
            compare(brightness.percent, 60);
            compare(backend.requests.length, reads);
            preview.coordinator.close(false);
            // Reopen during the fade too: refresh belongs to panel session.
            open(); settle(27);
            compare(feedback.count, 0);
            verify(!preview.osd.visible);
        }
        function test_vim_standard_input_and_final_drag() {
            open();
            const slider = control("brightnessSlider");
            control("audioVolume").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_J);
            verify(slider.activeFocus);
            verify(findChild(control("brightnessRow"), "focusIndicator").visible);
            verify(!findChild(slider, "focusIndicator").visible);
            keyClick(Qt.Key_L); settle(65);
            keyClick(Qt.Key_H); settle(60);
            keyClick(Qt.Key_Right); settle(65);
            keyClick(Qt.Key_Left); settle(60);
            keyClick(Qt.Key_Return); settle(60);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier); settle(60);
            keyClick(Qt.Key_K); verify(control("audioVolume").activeFocus);
            keyClick(Qt.Key_Tab); verify(slider.activeFocus);
            keyClick(Qt.Key_Backtab); verify(control("brightnessDetails").activeFocus);
            keyClick(Qt.Key_Tab); verify(slider.activeFocus, "Focus: " + scene.Window.window.activeFocusItem.objectName + "; tab: " + control("brightnessDetails").KeyNavigation.tab.objectName);
            const before = writes().length;
            mousePress(slider, slider.width * 0.6, slider.height / 2);
            for (let i = 1; i <= 30; i++) mouseMove(slider, slider.leftPadding + (slider.availableWidth * i / 30), slider.height / 2, 2);
            mouseRelease(slider, slider.width - slider.rightPadding, slider.height / 2);
            settle(100);
            compare(slider.value, 100);
            verify(writes().length - before < 15, "drag commands must be coalesced");
            keyClick(Qt.Key_Backtab); keyClick(Qt.Key_Space); keyClick(Qt.Key_J);
            verify(control("brightnessRefresh").activeFocus);
            keyClick(Qt.Key_Escape); verify(control("brightnessDetails").activeFocus);
            keyClick(Qt.Key_J); verify(control("settingsButton").activeFocus);
        }
        function test_lost_device_focus_and_small_panel() {
            scene.width = 320; scene.height = 220;
            open();
            const slider = control("brightnessSlider");
            slider.forceActiveFocus(Qt.TabFocusReason);
            wait(30);
            const surface = preview.panelHost.window;
            const position = slider.mapToItem(surface, 0, 0);
            verify(position.y >= 0 && position.y + slider.height <= surface.height);
            backend.devices = [];
            brightness.refresh();
            tryCompare(brightness, "busy", false);
            tryVerify(() => control("brightnessDetails").activeFocus);
            control("settingsButton").forceActiveFocus(Qt.TabFocusReason);
            brightness.refresh();
            tryCompare(brightness, "busy", false);
            verify(control("settingsButton").activeFocus);
        }
        function test_shared_osd_switches_kind_color_monitor_and_timer() {
            verify(!preview.osd.visible);
            preview.barController.focusBar();
            tryVerify(() => preview.Window.window.activeFocusItem.objectName.indexOf("workspace-") === 0);
            const focused = preview.Window.window.activeFocusItem;
            verify(brightness.setPercent(70, "TEST-2")); settle(70);
            tryCompare(preview.osdHost, "loaded", true);
            compare(preview.osd.kind, "brightness");
            compare(preview.osd.screen, preview.secondScreen);
            const item = preview.osdHost.window;
            compare(item.fillColor, Theme.accentSecondary);
            compare(item.label, "Jasność · 70%");
            compare(preview.Window.window.activeFocusItem, focused);
            verify(audio.setVolume(30, "TEST-1"));
            tryCompare(audio, "busy", false);
            compare(preview.osd.kind, "audio");
            compare(preview.osdHost.window, item);
            compare(item.fillColor, Theme.accent);
            verify(brightness.setPercent(80, "unknown")); settle(80);
            compare(preview.osd.kind, "brightness");
            compare(preview.osdHost.window, item);
            wait(300);
            verify(preview.osd.visible);
            tryCompare(preview.osdHost, "loaded", false, 1000);
            verify(brightness.setPercent(85, "TEST-2")); settle(85);
            preview.coordinator.screens = [preview.firstScreen];
            tryCompare(preview.osdHost, "loaded", false);
            open();
            verify(brightness.setPercent(45, "TEST-1")); settle(45);
            verify(!preview.osd.visible);
        }
    }
}
