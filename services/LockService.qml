import QtQuick

QtObject {
    id: root
    required property var backend
    required property var authentication
    property bool hold: false
    property int generation: 0
    property bool authenticating: false
    property bool unlocking: false
    property string fingerprintState: "idle"
    property bool passwordFailed: false
    property string lastError: ""
    readonly property bool locked: backend.locked
    readonly property bool secure: backend.secure
    readonly property bool passwordBusy: authentication.passwordBusy
    signal clearPassword()
    signal unlocked()

    function request(): bool {
        if (locked) {
            // A fresh lock request revokes an authenticated exit still fading.
            if (unlocking) { unlocking = false; fingerprintState = "idle"; sync(); }
            return true;
        }
        lastError = "";
        fingerprintState = "idle";
        passwordFailed = false;
        return backend.acquire();
    }
    function sync(): void {
        if (unlocking && (!locked || !secure || hold)) {
            unlocking = false;
            if (hold) fingerprintState = "idle";
        }
        if (locked && secure && !hold && !unlocking && !authenticating) {
            authenticating = true;
            authentication.begin(++generation);
        } else if ((!locked || !secure || hold || unlocking) && authenticating) {
            authenticating = false;
            ++generation;
            authentication.stop();
            clearPassword();
        }
    }
    function submit(password: string): bool {
        if (!locked || !secure || hold || !authenticating || passwordBusy) return false;
        passwordFailed = false;
        return authentication.submit(generation, password);
    }
    function accepted(epoch: int, method: string): void {
        if (epoch !== generation || !locked || !secure || hold || !authenticating) return;
        fingerprintState = method === "fingerprint" ? "success" : "idle";
        reset.stop();
        authenticating = false;
        ++generation;
        authentication.stop();
        clearPassword();
        unlocking = true;
    }
    function finishUnlock(): void {
        // Every surface has faded. Only a still-valid PAM success may release
        // the compositor lock; sleep or a new lock request revokes that success.
        if (!unlocking || !locked || !secure || hold) return;
        backend.release();
        unlocking = false;
        unlocked();
    }
    function rejected(epoch: int, method: string): void {
        if (epoch !== generation || !locked || hold) return;
        if (method === "fingerprint") fingerprintState = "error";
        else { passwordFailed = true; clearPassword(); }
        reset.restart();
    }
    onLockedChanged: { sync(); if (!locked) clearPassword(); }
    onSecureChanged: sync()
    onHoldChanged: sync()
    readonly property Timer reset: Timer {
        interval: 2000
        onTriggered: { root.fingerprintState = "idle"; root.passwordFailed = false; }
    }
    readonly property Connections authEvents: Connections {
        target: root.authentication
        function onSucceeded(epoch: int, method: string): void { root.accepted(epoch, method); }
        function onFailed(epoch: int, method: string): void { root.rejected(epoch, method); }
    }
    readonly property Connections lockEvents: Connections {
        target: root.backend
        function onFailed(message: string): void { root.lastError = message; }
    }
    Component.onCompleted: sync()
    Component.onDestruction: authentication.stop()
}
