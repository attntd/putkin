import QtQuick
import QtTest
import "../../services"
import "../../preview"
import "../../modules/screenshot"
import "../../core/Actions.js" as Actions

Item {
    id: scene
    width: 800; height: 600
    QtObject { id: screen; property string name: "TEST"; property int x: -800; property int y: 0; property int width: 800; property int height: 600 }
    MockScreenshotBackend { id: backend }
    ScreenshotService { id: service; backend: backend; screens: [screen] }
    SelectionView { id: selection; anchors.fill: parent; service: service; visible: service.selecting }
    ScreenshotPreview { id: preview; anchors.fill: parent; service: service; visible: service.previewing }
    TestCase {
        name: "Screenshot"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            service.close(); service.blocked = false; screen.width = 800;
            backend.captures = []; backend.saves = 0; backend.cancels = 0;
            verify(service.start({address: "123"}, "TEST"));
            selection.forceActiveFocus();
        }
        function cleanup() { service.close(); }
        function showPreview() {
            keyClick(Qt.Key_Return); service.unmapped();
            backend.captured("", 1600, 1200, "");
            compare(service.phase, "preview"); preview.forceActiveFocus();
        }
        function test_cancel_without_any_capture_data() { return [{key: Qt.Key_Q}, {key: Qt.Key_Escape}]; }
        function test_cancel_without_any_capture(data) {
            mouseDrag(selection, 300, 250, -200, -150);
            compare(backend.captures.length, 0);
            keyClick(data.key); compare(service.phase, "idle");
            service.unmapped(); compare(backend.captures.length, 0);
        }
        function test_reverse_drag_waits_for_enter_and_native_unmap() {
            mouseDrag(selection, 300, 250, -200, -150);
            compare(service.selection, Qt.rect(100, 100, 200, 150));
            compare(backend.captures.length, 0);
            keyClick(Qt.Key_Return); compare(service.phase, "hiding");
            compare(backend.captures.length, 0);
            service.unmapped(); service.unmapped();
            compare(backend.captures.length, 1);
            compare(backend.captures[0].mode, "region");
            compare(backend.captures[0].region, [100, 100, 200, 150]);
        }
        function test_click_and_zero_area_capture_whole_screen() {
            mouseClick(selection, 100, 100);
            keyClick(Qt.Key_Return); service.unmapped();
            compare(backend.captures[0].mode, "screen");
        }
        function test_window_preserves_target_and_overrides_selection() {
            service.select(1, 2, 10, 20);
            keyClick(Qt.Key_W); service.unmapped();
            compare(backend.captures[0].mode, "window");
            compare(backend.captures[0].window, "123");
        }
        function test_missing_window_stays_in_selection() {
            service.windowAddress = ""; keyClick(Qt.Key_W);
            compare(service.phase, "selecting"); verify(service.lastError.length > 0);
            compare(backend.captures.length, 0);
        }
        function test_hotplug_and_lock_cancel_before_capture() {
            keyClick(Qt.Key_Return); screen.width = 780;
            service.unmapped(); compare(backend.captures.length, 0);
            verify(service.start(null, "TEST")); service.blocked = true;
            compare(service.phase, "idle"); verify(!service.start(null, "TEST"));
        }
        function test_missing_monitor_does_not_capture_another_screen() {
            service.close(); verify(!service.start({address: "123"}, "MISSING"));
            compare(service.phase, "idle"); compare(backend.captures.length, 0);
        }
        function test_cancelled_request_ignores_late_result() {
            keyClick(Qt.Key_Return); service.unmapped(); service.close();
            backend.captured("", 10, 10, ""); compare(service.phase, "idle");
        }
        function test_preview_save_data() { return [{key: Qt.Key_F}, {key: Qt.Key_Return}, {key: Qt.Key_Enter}]; }
        function test_preview_save(data) {
            showPreview(); keyClick(data.key); compare(backend.saves, 1);
            keyClick(data.key); compare(backend.saves, 1);
            backend.saved("/test/saved.png"); compare(service.phase, "idle"); compare(service.savedPath, "/test/saved.png");
        }
        function test_preview_close_data() { return [{key: Qt.Key_Escape}, {key: Qt.Key_Q}]; }
        function test_preview_close(data) { showPreview(); keyClick(data.key); compare(service.phase, "idle"); compare(backend.saves, 0); }
        function test_save_failure_can_retry_and_fatal_clears() {
            showPreview(); keyClick(Qt.Key_F); backend.failed("Disk full", false);
            compare(service.phase, "preview"); compare(service.lastError, "Disk full");
            keyClick(Qt.Key_F); compare(backend.saves, 2);
            backend.failed("Worker lost", true); compare(service.phase, "idle");
        }
        function test_buttons_vim_and_pointer_focus() {
            showPreview(); keyClick(Qt.Key_J);
            const save = findChild(preview, "screenshotSave"), close = findChild(preview, "screenshotClose");
            verify(save.activeFocus); compare(save.focusReason, Qt.TabFocusReason);
            keyClick(Qt.Key_L); verify(close.activeFocus); keyClick(Qt.Key_H); verify(save.activeFocus);
            mousePress(save); compare(save.focusReason, Qt.MouseFocusReason);
            mouseRelease(save); compare(backend.saves, 1);
        }
        function test_keyboard_catalog_migrates_existing_settings() {
            const old = Actions.defaults().filter(row => row.action !== "screenshot");
            old[0].shortcut = "SUPER + ALT + SPACE"; old[0].command = ":start";
            const parsed = Actions.parse(JSON.stringify({schemaVersion: 1, bindings: old}));
            verify(!parsed.error); compare(parsed.value[0].command, ":start");
            compare(parsed.value.find(row => row.action === "screenshot"), {action: "screenshot", shortcut: "Print", command: ":screenshot"});
            compare(Actions.shortcut("print"), "Print");
            verify(!!Actions.parse(JSON.stringify({schemaVersion: 1, bindings: old.slice(1)})).error);
        }
    }
}
