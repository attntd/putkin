pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "services"
import "preview"
import "modules/lock"

ShellRoot {
    id: root
    property bool fingerprint: false
    property bool captureEnabled: true
    property bool idleEnabled: false
    property var fadeFrames: []
    PersistentProperties { id: retained; reloadableId: "test-lock-state"; property bool locked: false }
    Binding { target: Quickshell; property: "watchFiles"; value: !retained.locked }
    PamBackend { id: auth; configDirectory: Quickshell.env("PUTKIN_TEST_PAM"); fingerprintAvailable: root.fingerprint && bridge.fingerprintAvailable }
    LockHost { id: host; service: lock; state: retained; screens: root.captureEnabled ? Quickshell.screens : [] }
    LockService { id: lock; backend: host; authentication: auth; hold: bridge.unlockHeld }
    SessionBackend { id: bridge; lockService: lock }
    SessionService { id: session; backend: bridge }
    MockBrightnessBackend { id: backlight }
    BrightnessService { id: brightness; backend: backlight }
    IdleService { id: idle; brightness: brightness; session: session; display: monitors; idleBlocked: bridge.idleInhibited; sleepBlocked: bridge.sleepInhibited }
    QtObject {
        id: idleBridge
        readonly property bool idleReady: bridge.idleReady && root.idleEnabled
        function setIdleHint(value: bool): void { bridge.setIdleHint(value); }
    }
    IdleBackend { id: monitors; service: idle; bridge: idleBridge; dimSeconds: 2; displaySeconds: 3; lockSeconds: 4; sleepSeconds: 8 }
    Connections { target: session; function onResumed(): void { idle.resume(); brightness.refresh(); } }
    FrameAnimation {
        running: lock.locked
        onTriggered: {
            const opacities = host.views.map(view => view.opacity);
            if (root.fadeFrames.length < 60 || lock.unlocking)
                root.fadeFrames = root.fadeFrames.concat([{
                    closing: lock.unlocking, secure: lock.secure, opacities: opacities
                }]).slice(-120);
        }
    }
    Variants {
        model: Quickshell.screens
        // Same runtime platform factory as BarWindow; 0.3.1 metadata exposes
        // only its abstract interface. Keep import/type diagnostics enabled.
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            required property ShellScreen modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "putkin-test-desktop"
            color: "#d45040"
            Rectangle { width: parent.width / 2; height: parent.height / 2; color: "#309080" }
            Rectangle { x: parent.width / 2; width: parent.width / 2; height: parent.height / 2; color: "#5070c0" }
            Rectangle { y: parent.height / 2; width: parent.width / 2; height: parent.height / 2; color: "#d0b040" }
        }
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({ready: bridge.ready && bridge.confirmationAvailable, error: bridge.errorText || session.lastError,
                locked: lock.locked, secure: lock.secure, hold: lock.hold, surfaces: host.surfaceCount, lua: Hyprland.usingLua, idleError: idle.lastError,
                screens: Quickshell.screens.map(s => s.name), fingerprint: lock.fingerprintState,
                fingerprintActive: auth.finger.active, unlocking: lock.unlocking,
                opacities: host.views.map(view => view.opacity), fadeFrames: root.fadeFrames,
                capturing: host.capture.capturing, captures: host.capture.frames.length,
                animated: host.views.map(view => view.animate),
                sleepAvailable: session.capability("idleSuspend").available,
                passwordFailed: lock.passwordFailed, passwordBusy: auth.passwordBusy,
                dimmed: idle.dimmed, percent: brightness.percent, displaysOff: idle.displaysOff,
                idleInhibited: bridge.idleInhibited, sleepInhibited: bridge.sleepInhibited, watching: Quickshell.watchFiles});
        }
        function request(): bool { root.fadeFrames = []; return session.request("lock"); }
        function fingerprintEnabled(value: bool): void { root.fingerprint = value; }
        function captureEnabled(value: bool): void { root.captureEnabled = value; }
        function enableIdle(value: bool): void { root.idleEnabled = value; }
        function refresh(): void { session.refresh(); }
        function reload(): string { if (lock.locked) return "deferred"; Quickshell.reload(false); return "accepted"; }
    }
}
