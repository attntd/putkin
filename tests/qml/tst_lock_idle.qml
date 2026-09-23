pragma ComponentBehavior: Bound
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
    LockView {
        id: view
        anchors.fill: parent
        service: lock
        date: new Date(2026, 8, 20, 22, 57)
        onHidden: lock.finishUnlock()
    }
    Component { id: freshView; LockView { width: 800; height: 600; service: lock } }
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
        property bool sleepAvailable: true
        function capability(action: string): var { return { available: action === "idleSuspend" && sleepAvailable }; }
        function request(action: string): bool { calls = calls.concat([action]); return true; }
    }
    IdleService { id: idle; brightness: brightness; session: session; display: display }
    TestCase {
        name: "LockIdle"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            protocol.release(); lock.hold = false;
            tryCompare(view, "opacity", 0);
            protocol.acquisitions = 0; protocol.releases = 0;
            pam.attempts = 0;
            lock.fingerprintState = "idle"; lock.passwordFailed = false;
            view.passwordField.clear();
            idle.idleBlocked = false; idle.sleepBlocked = false;
            idle.resume();
            brightness.available = true; brightness.busy = false;
            brightness.percent = 65; brightness.device = "test-backlight";
            brightness.calls = []; display.calls = []; session.calls = []; session.sleepAvailable = true;
        }
        function type(text) { for (const letter of text) keyClick(letter); }
        function secure() {
            verify(lock.request()); protocol.secure = true; verify(pam.enabled);
            tryCompare(view, "opacity", 1);
        }
        function test_protocol_and_authentication_are_both_required() {
            verify(lock.request()); verify(lock.request());
            compare(protocol.acquisitions, 1); verify(!pam.enabled);
            pam.succeeded(lock.generation, "password"); verify(protocol.locked);
            protocol.secure = true;
            pam.failed(lock.generation, "password"); verify(protocol.locked); verify(lock.passwordFailed);
            pam.succeeded(lock.generation - 1, "password"); verify(protocol.locked);
            lock.finishUnlock(); verify(protocol.locked);
            pam.succeeded(lock.generation, "password"); tryCompare(protocol, "locked", false);
            compare(protocol.releases, 1);
        }
        function test_hold_invalidates_late_authentication() {
            secure(); const old = pam.epoch;
            lock.hold = true; verify(!pam.enabled);
            pam.succeeded(old, "fingerprint"); verify(protocol.locked);
            lock.hold = false; verify(pam.enabled); verify(pam.epoch > old);
            pam.succeeded(old, "password"); verify(protocol.locked);
            pam.succeeded(pam.epoch, "fingerprint"); compare(lock.fingerprintState, "success");
            tryCompare(protocol, "locked", false);
        }
        function test_fade_keeps_protocol_locked_until_content_disappears() {
            verify(lock.request()); protocol.secure = true;
            tryVerify(() => view.opacity > 0 && view.opacity < 1);
            verify(protocol.secure);
            tryCompare(view, "opacity", 1);
            pam.succeeded(pam.epoch, "password");
            verify(lock.unlocking); verify(!pam.enabled); verify(view.passwordField.readOnly);
            verify(!lock.submit("ignored"));
            tryVerify(() => view.opacity > 0 && view.opacity < 1);
            verify(protocol.locked && protocol.secure); compare(protocol.releases, 0);
            tryCompare(protocol, "locked", false);
            compare(view.opacity, 0); compare(protocol.releases, 1);
        }
        function test_new_surface_fades_in_while_already_locked() {
            secure();
            const added = createTemporaryObject(freshView, scene);
            compare(added.opacity, 0);
            tryVerify(() => added.opacity > 0 && added.opacity < 1);
            tryCompare(added, "opacity", 1);
        }
        function test_missing_desktop_frame_shows_opaque_lock_immediately() {
            secure();
            const added = createTemporaryObject(freshView, scene, {animate: false});
            compare(added.opacity, 1);
            verify(waitForRendering(added));
            compare(added.opacity, 1);
        }
        function test_password_has_no_caret_but_still_accepts_input() {
            secure();
            const field = view.passwordField;
            mouseClick(field);
            verify(field.activeFocus);
            for (let frame = 0; frame < 5; ++frame) {
                wait(250);
                const painted = grabImage(field);
                const ratio = painted.width / field.width;
                const y = Math.round(field.height / 2 * ratio);
                const background = painted.pixel(Math.round(field.width / 2 * ratio), y);
                for (let x = field.leftPadding; x < field.leftPadding + 12; ++x)
                    compare(painted.pixel(Math.round(x * ratio), y), background, "empty input pixel " + x);
            }
            type("hjkl"); compare(field.text, "hjkl");
            keyClick(Qt.Key_Return); compare(pam.submitted, "hjkl");
        }
        function test_sleep_or_new_request_revokes_fading_unlock_data() {
            return [{tag: "sleep", sleep: true}, {tag: "new-lock", sleep: false}];
        }
        function test_sleep_or_new_request_revokes_fading_unlock(data) {
            secure(); const old = pam.epoch;
            pam.succeeded(old, "fingerprint");
            tryVerify(() => view.opacity > 0 && view.opacity < 1);
            if (data.sleep) lock.hold = true;
            else verify(lock.request());
            verify(!lock.unlocking);
            lock.finishUnlock(); pam.succeeded(old, "password");
            tryCompare(view, "opacity", 1);
            verify(protocol.locked && protocol.secure); compare(protocol.releases, 0);
            if (data.sleep) { verify(!pam.enabled); lock.hold = false; }
            verify(pam.enabled); verify(pam.epoch > old);
            pam.succeeded(pam.epoch, "password");
            tryCompare(protocol, "locked", false);
        }
        function test_fingerprint_is_right_of_password_even_with_long_input() {
            secure();
            const field = view.passwordField;
            const finger = findChild(field, "lockFingerprint");
            for (const width of [800, 320]) {
                scene.width = width;
                field.forceActiveFocus(Qt.OtherFocusReason);
                type("hjkl".repeat(20));
                verify(finger.x > field.width / 2);
                verify(field.rightPadding >= finger.width);
                verify(field.cursorRectangle.x + field.cursorRectangle.width <= finger.x);
                compare(field.text.length, 80);
                keyClick(Qt.Key_Escape);
            }
            scene.width = 800;
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
        function test_unavailable_automatic_sleep_is_not_requested() {
            session.sleepAvailable = false;
            idle.lock(true); idle.suspend(true); idle.suspend(true);
            compare(session.calls, ["lock"]); verify(!idle.suspendSent);
            session.sleepAvailable = true;
            idle.suspend(false); idle.suspend(true);
            compare(session.calls, ["lock", "idleSuspend"]);
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
