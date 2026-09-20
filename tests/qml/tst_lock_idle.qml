import QtQuick
import QtTest
import "../../services"
import "../../preview"
import "../../modules/lock"

Item {
    id: scene
    width: 800; height: 600
    MockLockBackend { id: protocol }
    MockPamBackend { id: pam }
    LockService { id: lock; backend: protocol; authentication: pam }
    LockView { id: view; anchors.fill: parent; service: lock; date: new Date(2026, 8, 20, 22, 57) }
    QtObject {
        id: brightness
        property bool available: true
        property bool busy: false
        property string device: "test-backlight"
        property real percent: 65
        property var calls: []
        function setIdlePercent(value: real): bool { calls = calls.concat([value]); percent = value; return available; }
    }
    QtObject {
        id: display
        property var calls: []
        function setEnabled(value: bool): bool { calls = calls.concat([value]); return true; }
    }
    QtObject {
        id: session
        property var calls: []
        function request(action: string): bool { calls = calls.concat([action]); return true; }
    }
    IdleService { id: idle; brightness: brightness; session: session; display: display }
    TestCase {
        name: "LockIdle"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            protocol.release(); lock.hold = false;
            protocol.acquisitions = 0; protocol.releases = 0;
            pam.attempts = 0;
            lock.fingerprintState = "idle"; lock.passwordFailed = false;
            view.passwordField.clear();
            idle.idleBlocked = false; idle.sleepBlocked = false;
            idle.resume();
            brightness.available = true; brightness.busy = false;
            brightness.percent = 65; brightness.device = "test-backlight";
            brightness.calls = []; display.calls = []; session.calls = [];
        }
        function type(text) { for (const letter of text) keyClick(letter); }
        function secure() { verify(lock.request()); protocol.secure = true; verify(pam.enabled); }
        function test_protocol_and_authentication_are_both_required() {
            verify(lock.request()); verify(lock.request());
            compare(protocol.acquisitions, 1); verify(!pam.enabled);
            pam.succeeded(lock.generation, "password"); verify(protocol.locked);
            protocol.secure = true;
            pam.failed(lock.generation, "password"); verify(protocol.locked); verify(lock.passwordFailed);
            pam.succeeded(lock.generation - 1, "password"); verify(protocol.locked);
            pam.succeeded(lock.generation, "password"); verify(!protocol.locked);
            compare(protocol.releases, 1);
        }
        function test_hold_invalidates_late_authentication() {
            secure(); const old = pam.epoch;
            lock.hold = true; verify(!pam.enabled);
            pam.succeeded(old, "fingerprint"); verify(protocol.locked);
            lock.hold = false; verify(pam.enabled); verify(pam.epoch > old);
            pam.succeeded(old, "password"); verify(protocol.locked);
            pam.succeeded(pam.epoch, "fingerprint"); verify(!protocol.locked);
            compare(lock.fingerprintState, "success");
        }
        function test_password_input_hjkl_enter_escape_and_duplicate() {
            secure(); view.passwordField.forceActiveFocus(Qt.OtherFocusReason);
            type("hjkl test"); compare(view.passwordField.text, "hjkl test");
            keyClick(Qt.Key_Return);
            compare(pam.submitted, "hjkl test"); compare(view.passwordField.text, "");
            keyClick(Qt.Key_Return); compare(pam.attempts, 1);
            pam.passwordBusy = false; pam.failed(pam.epoch, "password");
            type("abc"); keyClick(Qt.Key_Escape);
            compare(view.passwordField.text, ""); verify(protocol.locked);
        }
        function test_keyboard_focus_and_pointer_hide_frame() {
            secure(); const field = view.passwordField;
            const frame = findChild(field, "focusIndicator");
            mouseClick(field); verify(!frame.visible);
            keyClick(Qt.Key_H); verify(frame.visible);
            mouseClick(field); verify(!frame.visible);
        }
        function test_fingerprint_error_resets_without_unlock() {
            secure(); pam.failed(pam.epoch, "fingerprint");
            compare(lock.fingerprintState, "error"); verify(protocol.locked);
            tryCompare(lock, "fingerprintState", "idle", 2500);
            verify(protocol.locked);
        }
        function test_idle_threshold_actions_and_restore() {
            idle.dim(true); idle.dim(true); compare(brightness.calls, [10]);
            idle.screen(true); idle.screen(true); compare(display.calls, [false]);
            idle.lock(true); idle.suspend(true); idle.suspend(true);
            compare(session.calls, ["lock", "idleSuspend"]);
            idle.screen(false); idle.dim(false);
            compare(display.calls, [false, true]); compare(brightness.calls, [10, 65]);
            idle.suspend(false); idle.suspend(true); compare(session.calls.length, 3);
        }
        function test_presentation_restores_and_blocks_automatic_actions() {
            idle.dim(true); idle.screen(true);
            idle.idleBlocked = true; idle.sleepBlocked = true;
            compare(brightness.percent, 65); compare(display.calls, [false, true]);
            idle.dim(true); idle.screen(true); idle.lock(true); idle.suspend(true);
            compare(session.calls.length, 0); compare(brightness.percent, 65);
            verify(lock.request()); verify(protocol.locked);
        }
        function test_background_allows_lock_and_display_but_no_sleep() {
            idle.sleepBlocked = true;
            idle.dim(true); idle.screen(true); idle.lock(true); idle.suspend(true);
            compare(brightness.percent, 10); compare(display.calls, [false]); compare(session.calls, ["lock"]);
        }
        function test_missing_or_replaced_backlight_and_resume() {
            brightness.available = false; idle.dim(true); verify(!idle.dimmed);
            brightness.available = true; brightness.percent = 5; idle.dim(true); compare(brightness.calls, []);
            brightness.percent = 65; idle.dim(true);
            brightness.device = "different"; idle.resume();
            compare(brightness.calls, [10]); compare(display.calls, [true]);
        }
    }
}
