// Real Process/IPC/LazyLoader with an explicitly injected fake executable.
// This entrypoint cannot fall back to the host's brightnessctl.
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "preview"

ShellRoot {
    BrightnessBackend { id: backend; executable: Quickshell.env("PUTKIN_TEST_BRIGHTNESSCTL") || "/putkin-test-missing-brightnessctl" }
    BrightnessService { id: brightnessService; backend: backend }
    BrightnessIpc { brightness: brightnessService }
    MockAudioBackend { id: audioBackend }
    AudioService { id: audioService; backend: audioBackend }
    AudioIpc { audio: audioService }
    PanelPreviewWindow { id: window; audio: audioService; brightness: brightnessService }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const scene = window.scene;
            return JSON.stringify({
                available: brightnessService.available, percent: brightnessService.percent,
                device: brightnessService.device, busy: brightnessService.busy,
                error: brightnessService.lastError, diagnostic: brightnessService.diagnostic,
                child: backend.processId, osd: scene.osd.visible, kind: scene.osd.kind,
                osdLoaded: scene.osdHost.loaded, created: scene.osdCreated, destroyed: scene.osdDestroyed,
                screen: scene.osd.screen ? scene.osd.screen.name : "", panel: scene.coordinator.activeId,
                focus: scene.Window.window && scene.Window.window.activeFocusItem ? scene.Window.window.activeFocusItem.objectName : ""
            });
        }
        function burst(count: int): void { for (let i = 0; i < count; i++) brightnessService.change(1, "TEST-2"); }
        function executable(path: string): void { backend.executable = path; }
        function hideOsd(): void { window.scene.osd.hide(); }
        function timeout(milliseconds: int): void { window.scene.osd.timeout = milliseconds; }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
