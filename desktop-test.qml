import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "preview"

ShellRoot {
    NightLightBackend { id: backend; helperPath: Quickshell.shellPath("tests/night_light_fixture.py"); commandTimeout: 1600 }
    NightLightService { id: night; backend: backend }
    PanelPreviewWindow { id: preview; nightLight: night }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({ available: night.available, enabled: night.enabled, temperature: night.temperature,
                sample: night.sample, busy: night.busy, error: night.lastError, pid: backend.processId,
                panelLoaded: preview.scene.panelHost.loaded, created: preview.scene.createdCount, destroyed: preview.scene.destroyedCount });
        }
        function refresh(): void { night.refresh(); }
        function enable(value: bool): bool { return night.setEnabled(value); }
        function temperature(value: int): bool { return night.setTemperature(value); }
        function productionOwner(): void { backend.helperPath = Quickshell.shellPath("services/night_light.py"); night.refresh(); }
        function testOwner(): void { backend.helperPath = Quickshell.shellPath("tests/night_light_fixture.py"); night.refresh(); }
        function reload(): void { Quickshell.reload(false); }
    }
}
