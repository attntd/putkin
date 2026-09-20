import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "preview"

ShellRoot {
    MockLockBackend { id: protocol }
    MockPamBackend { id: pam }
    LockService { id: lock; backend: protocol; authentication: pam; hold: backend.unlockHeld }
    SessionBackend {
        id: backend
        lockService: lock
        helperPath: Quickshell.env("PUTKIN_SESSION_HELPER") || Quickshell.shellPath("services/session_backend.py")
        helperEnvironment: ({ WAYLAND_DISPLAY: "test-wayland", HYPRLAND_INSTANCE_SIGNATURE: "test-instance" })
    }
    SessionService { id: service; backend: backend }
    MockBrightnessBackend { id: backlight }
    BrightnessService { id: brightness; backend: backlight }
    PanelPreviewWindow { id: window; sessionService: service; brightness: brightness }
    SessionIpc { service: service; coordinator: window.scene.coordinator }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({ ready: backend.ready, pid: backend.processId, busy: service.busy, error: service.lastError,
                result: service.resultText, capabilities: backend.capabilities, sessionId: backend.sessionId,
                confirmation: backend.confirmationAvailable, phase: service.phase,
                locked: lock.locked, secure: lock.secure, hold: lock.hold, token: backend.lockToken,
                idleReady: backend.idleReady, idleInhibited: backend.idleInhibited, sleepInhibited: backend.sleepInhibited,
                refreshes: backlight.requests.length, loaded: window.scene.panelHost.loaded,
                active: window.scene.coordinator.activeId, created: window.scene.createdCount, destroyed: window.scene.destroyedCount });
        }
        function request(action: string): bool { return service.request(action); }
        function confirm(): void { protocol.secure = true; }
        function release(): void { protocol.release(); }
        function stale(token: int): void { backend.send({action: "lock-state", token: token, locked: true, secure: true}); }
        function refresh(): void { service.refresh(); }
        function choose(action: string): void { window.scene.panelHost.window.page.choose(action); }
        function cancel(): void { window.scene.panelHost.window.page.dismissOrCollapse(); }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
