import QtQuick
import QtTest
import "../../services"
import "../../modules/authentication"
import "../../core"
import "../../services/AuthenticationMessages.js" as Messages

Item {
    id: scene
    width: 700; height: 600
    AuthenticationService { id: service }
    Component { id: requestFactory; AuthenticationRequest {} }
    Component { id: polkitFactory; PolkitRequest {} }
    Component {
        id: flowFactory
        QtObject {
            property string message: "Fixture application — operation"
            property bool isResponseRequired: false
            property bool responseVisible: false
            property string inputPrompt: ""
            property string supplementaryMessage: ""
            property bool supplementaryIsError: false
            property bool isCancelled: false
            property var identities: [{displayName: "Fixture user", string: "fixture"}, {displayName: "Other user", string: "other"}]
            property var selectedIdentity: identities[0]
            property string response: ""
            signal authenticationSucceeded()
            signal authenticationFailed()
            function submit(value) { response = value; isResponseRequired = false; }
            function cancelAuthenticationRequest() { isCancelled = true; }
        }
    }
    AuthenticationView { id: view; request: service.current; width: 420; height: Math.min(implicitHeight, scene.height); anchors.centerIn: parent }
    TestCase {
        name: "Authentication"
        when: windowShown
        function init() { failOnWarning(/.*/); service.blocked = false; scene.width = 700; scene.height = 600; }
        function cleanup() { service.cancelAll(); tryCompare(service, "current", null); compare(service.pending.length, 0); }
        function open(properties) {
            const request = requestFactory.createObject(scene, properties || {});
            verify(service.enqueue(request));
            tryCompare(view, "opacity", 1);
            return request;
        }
        function polkit(timeoutMs = 1000) {
            const flow = createTemporaryObject(flowFactory, scene);
            const request = polkitFactory.createObject(scene, {flow: flow, fingerprintTimeoutMs: timeoutMs});
            verify(service.enqueue(request));
            tryCompare(view, "opacity", 1);
            return {flow: flow, request: request};
        }
        function type(text) { for (const char of text) keyClick(char); }
        function test_hjkl_secret_cleared_single_submit() {
            const request = open();
            let responses = [];
            request.answered.connect((value, accepted) => { responses.push([value, accepted]); });
            mouseClick(view.passwordField);
            type("hjklq"); compare(view.passwordField.text, "hjklq");
            keyClick(Qt.Key_Return); keyClick(Qt.Key_Return);
            compare(responses, [["hjklq", true]]); compare(view.passwordField.text, "");
        }
        function test_pointer_and_keyboard_focus() {
            open();
            const field = view.passwordField, indicator = findChild(field, "focusIndicator");
            mouseClick(field); verify(!indicator.visible);
            keyClick(Qt.Key_H); verify(indicator.visible);
            mousePress(field); mouseMove(field, 10, 10); mouseRelease(field); verify(!indicator.visible);
        }
        function test_confirmation_navigation_and_cancel_data() {
            return [{tag: "enter", key: Qt.Key_Return}, {tag: "escape", key: Qt.Key_Escape}, {tag: "q", key: Qt.Key_Q}];
        }
        function test_confirmation_navigation_and_cancel(data) {
            const request = open({mode: "confirm", title: "Zezwól na użycie klucza", acceptText: "Zezwól"});
            const cancel = findChild(view, "authCancel"), accept = findChild(view, "authAccept");
            cancel.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_L); verify(accept.activeFocus);
            keyClick(Qt.Key_H); verify(cancel.activeFocus);
            keyClick(data.key); verify(request.done);
            verify(!view.enabled); verify(view.visible);
        }
        function test_q_cancels_polkit_without_password() {
            const pair = polkit();
            findChild(view, "authCancel").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Q);
            verify(pair.flow.isCancelled);
            verify(pair.request.done);
        }
        function test_fingerprint_only_mismatch_and_device_error() {
            const pair = polkit(), flow = pair.flow, request = pair.request;
            flow.supplementaryMessage = "Place your right index finger on the fingerprint reader";
            compare(request.fingerprintState, "idle"); compare(request.errorText, "");
            verify(!view.passwordField.visible);
            flow.supplementaryIsError = true;
            flow.supplementaryMessage = "Failed to match fingerprint";
            compare(request.fingerprintState, "error"); compare(request.errorText, "");
            compare(findChild(view, "authFingerprint").color, Theme.error);
            tryCompare(request, "fingerprintState", "idle", 2500);
            flow.supplementaryMessage = "Device already in use by another user";
            verify(request.errorText.indexOf("Błąd czytnika") === 0);
            verify(findChild(view, "authError").visible);
            verify(!request.done);
        }
        function test_fingerprint_success_and_password_not_green() {
            const pair = polkit();
            pair.flow.supplementaryMessage = "Proszę umieścić palec na urządzeniu";
            pair.flow.authenticationSucceeded();
            compare(pair.request.fingerprintState, "success"); verify(pair.request.done);
            tryCompare(service, "current", null);
            const other = polkit();
            other.flow.supplementaryMessage = "Place your finger on the fingerprint reader";
            other.flow.isResponseRequired = true; other.flow.inputPrompt = "Password:";
            compare(other.request.fingerprintState, "hidden");
            other.request.submit("fixture"); other.flow.authenticationSucceeded();
            compare(other.request.fingerprintState, "hidden");
        }
        function test_mismatch_then_immediate_password_preserves_red_feedback() {
            const pair = polkit();
            pair.flow.supplementaryMessage = "Place your finger on the fingerprint reader";
            pair.flow.supplementaryIsError = true;
            pair.flow.supplementaryMessage = "Failed to match fingerprint";
            pair.flow.isResponseRequired = true; pair.flow.inputPrompt = "Password:";
            compare(pair.request.fingerprintState, "error"); compare(pair.request.errorText, "");
            verify(view.passwordField.visible); verify(findChild(view, "authFingerprint").visible);
            tryCompare(pair.request, "fingerprintState", "hidden", 2500);
            verify(view.passwordField.visible);
        }
        function test_password_retry_and_identity_clear() {
            const pair = polkit();
            pair.flow.isResponseRequired = true; pair.flow.inputPrompt = "Password:";
            tryVerify(() => view.passwordField.visible);
            mouseClick(view.passwordField); type("hjkl");
            pair.request.selectIdentity(1); compare(view.passwordField.text, "");
            compare(pair.flow.selectedIdentity, pair.flow.identities[1]);
            pair.request.submit("wrong"); pair.flow.authenticationFailed();
            verify(pair.request.invalid); verify(pair.request.errorText.length > 0);
            pair.flow.isResponseRequired = true;
            verify(view.passwordField.visible);
        }
        function test_countdown_becomes_focused_password_only_when_polkit_requests_it() {
            const pair = polkit(350), request = pair.request, flow = pair.flow;
            flow.supplementaryMessage = "Place your finger on the fingerprint reader";
            const slot = findChild(view, "authInputSlot"), track = findChild(view, "authCountdown");
            const fill = findChild(view, "authCountdownFill"), glyph = findChild(view, "authFingerprint");
            verify(waitForRendering(view));
            const geometry = [slot.x, slot.y, slot.width, slot.height, view.height];
            verify(track.visible); verify(glyph.visible); verify(!view.passwordField.visible);
            verify(glyph.x > slot.width / 2);
            tryVerify(() => request.fingerprintProgress > .2 && request.fingerprintProgress < 1);
            verify(fill.width > 0); verify(fill.x + fill.width < glyph.x);
            tryCompare(request, "fingerprintProgress", 1);
            // The estimated deadline never fabricates a native password prompt.
            verify(track.visible); verify(!view.passwordField.visible); verify(!request.done);
            flow.supplementaryMessage = "Verification timed out";
            // PAM may emit its password prompt in a later event batch.
            verify(waitForRendering(view));
            verify(slot.visible); verify(!view.passwordField.visible); verify(!glyph.visible);
            compare([slot.x, slot.y, slot.width, slot.height, view.height], geometry);
            flow.isResponseRequired = true; flow.inputPrompt = "Password:";
            tryVerify(() => view.passwordField.activeFocus);
            verify(!track.visible); verify(!glyph.visible);
            compare([slot.x, slot.y, slot.width, slot.height, view.height], geometry);
            verify(findChild(view.passwordField, "focusIndicator").visible);
            type("hjkl"); compare(view.passwordField.text, "hjkl");
            mouseClick(view.passwordField);
            verify(!findChild(view.passwordField, "focusIndicator").visible);
            keyClick(Qt.Key_Return); compare(flow.response, "hjkl");
        }
        function test_early_password_and_cancel_stop_countdown() {
            const pair = polkit(30000);
            pair.flow.supplementaryMessage = "Place your finger on the fingerprint reader";
            verify(pair.request.countdown.running);
            pair.flow.isResponseRequired = true; pair.flow.inputPrompt = "Password:";
            tryVerify(() => view.passwordField.activeFocus);
            verify(!pair.request.countdown.running); compare(pair.request.fingerprintProgress, 1);
            verify(!findChild(view, "authFingerprint").visible);
            pair.request.cancel(); tryCompare(service, "current", null);
            const next = polkit();
            next.flow.supplementaryMessage = "Place your finger on the fingerprint reader";
            verify(next.request.countdown.running);
            service.blocked = true;
            verify(next.request.done); verify(!next.request.countdown.running);
        }
        function test_scan_retry_preserves_countdown_and_identity_restarts_it() {
            const pair = polkit(1500);
            pair.flow.supplementaryMessage = "Place your finger on the fingerprint reader";
            tryVerify(() => pair.request.fingerprintProgress > .2);
            const progress = pair.request.fingerprintProgress;
            pair.flow.supplementaryMessage = "Swipe was too short";
            pair.flow.supplementaryMessage = "Place your finger on the fingerprint reader";
            verify(pair.request.fingerprintProgress >= progress);
            pair.request.selectIdentity(1);
            compare(pair.request.fingerprintProgress, 0); verify(!pair.request.countdown.running);
            pair.flow.supplementaryMessage = "Place your right index finger on the fingerprint reader";
            verify(pair.request.countdown.running);
        }
        function test_timeout_configuration() {
            compare(Messages.fingerprintTimeout("# auth sufficient pam_fprintd.so timeout=4\nauth sufficient pam_fprintd.so max-tries=1 timeout=30 # timeout=2"), 30000);
            compare(Messages.fingerprintTimeout("auth [success=done default=ignore] /usr/lib/security/pam_fprintd.so timeout=7"), 7000);
            compare(Messages.fingerprintTimeout("auth sufficient pam_fprintd.so"), 30000);
            compare(Messages.fingerprintTimeout("auth sufficient pam_fprintd.so timeout=-1"), 0);
            compare(Messages.fingerprintTimeout("auth sufficient pam_fprintd.so timeout=invalid"), 0);
            compare(Messages.fingerprintTimeout("auth include system-auth"), 0);
            compare(Messages.fingerprintTimeout("auth sufficient pam_fprintd.so\nauth optional pam_fprintd.so"), 0);
        }
        function test_queue_lock_and_disconnect() {
            const first = open();
            const second = requestFactory.createObject(scene) as AuthenticationRequest;
            const third = requestFactory.createObject(scene) as AuthenticationRequest;
            verify(service.enqueue(second)); verify(service.enqueue(third));
            compare(service.count, 3);
            second.finish(); compare(service.pending.length, 1);
            first.finish(); verify(!service.active); compare(service.current, first);
            tryCompare(service, "current", third);
            service.blocked = true; verify(third.done);
            tryCompare(service, "count", 0);
            const blocked = requestFactory.createObject(scene);
            verify(!service.enqueue(blocked)); compare(service.count, 0);
        }
        function test_text_is_plain_and_small_window() {
            scene.width = 320; scene.height = 220; view.width = 288;
            const request = open({context: "<b>literal</b> " + "x".repeat(300), mode: "confirm"});
            const cancel = findChild(view, "authCancel");
            cancel.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Escape);
            verify(request.done);
            view.width = 420;
        }
        function test_prompt_classification() {
            compare(Messages.describe("ssh", "input", "Enter PIN for YubiKey", "").title, "Odblokuj YubiKey");
            compare(Messages.describe("ssh", "input", "Enter PIN for YubiKey", "").context, "Wprowadź PIN klucza");
            compare(Messages.describe("ssh", "input", "Enter PIN for authenticator", "").title, "Odblokuj klucz sprzętowy");
            compare(Messages.describe("ssh", "input", "Enter passphrase for key '/fixture'", "").title, "Odblokuj klucz SSH");
            compare(Messages.describe("ssh", "input", "Enter passphrase for key '/fixture':", "").context, "/fixture");
            compare(Messages.describe("gpg", "input", "Please unlock for signing", "").title, "Podpisz kluczem GPG");
            compare(Messages.describe("gpg", "input", "Decrypt fixture", "").title, "Odszyfruj dane");
            compare(Messages.fingerprint("Dopasowanie odcisku palca się nie powiodło"), "mismatch");
            compare(Messages.fingerprint("Unrecognized hardware failure"), "");
        }
    }
}
