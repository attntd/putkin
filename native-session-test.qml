pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "services"
import "preview"
import "modules/lock"

ShellRoot {
    id: root
    property bool fingerprint: false
    property bool idleEnabled: false
    PersistentProperties { id: retained; reloadableId: "test-lock-state"; property bool locked: false }
    Binding { target: Quickshell; property: "watchFiles"; value: !retained.locked }
    PamBackend { id: auth; configDirectory: Quickshell.env("PUTKIN_TEST_PAM"); fingerprintAvailable: root.fingerprint }
    LockHost { id: host; service: lock; state: retained }
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
    Variants {
        model: Quickshell.screens
        // Same runtime platform factory as BarWindow; 0.3.1 metadata exposes
        // only its abstract interface. Keep import/type diagnostics enabled.
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            required property ShellScreen modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 32
            color: "#1e1e2e"
        }
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({ready: bridge.ready && bridge.confirmationAvailable, error: bridge.errorText || session.lastError,
                locked: lock.locked, secure: lock.secure, hold: lock.hold, surfaces: host.surfaceCount, lua: Hyprland.usingLua, idleError: idle.lastError,
                screens: Quickshell.screens.map(s => s.name), fingerprint: lock.fingerprintState,
                passwordFailed: lock.passwordFailed, passwordBusy: auth.passwordBusy,
                dimmed: idle.dimmed, percent: brightness.percent, displaysOff: idle.displaysOff,
                idleInhibited: bridge.idleInhibited, sleepInhibited: bridge.sleepInhibited, watching: Quickshell.watchFiles});
        }
        function request(): bool { return session.request("lock"); }
        function fingerprintEnabled(value: bool): void { root.fingerprint = value; }
        function enableIdle(value: bool): void { root.idleEnabled = value; }
        function reload(): string { if (lock.locked) return "deferred"; Quickshell.reload(false); return "accepted"; }
    }
}
