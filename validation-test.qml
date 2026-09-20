// Test-only composition. Started by scripts/test-validation-integration with
// private XDG/D-Bus and all hardware/session dependencies replaced explicitly.
import QtQuick
import Quickshell
import Quickshell.Io
import "preview"
import "services"

ShellRoot {
    PanelPreviewWindow { id: preview }
    AudioIpc { audio: preview.audio }
    BrightnessIpc { brightness: preview.brightness }
    SessionIpc { service: preview.sessionService; coordinator: preview.scene.coordinator }
    NotificationIpc { service: preview.notifications; controller: preview.scene.notificationController }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const scene = preview.scene;
            return JSON.stringify({
                loaded: scene.panelHost.loaded, created: scene.createdCount, destroyed: scene.destroyedCount,
                surface: scene.coordinator.activeId, screen: scene.coordinator.screenName,
                editing: preview.settings.editing, accent: preview.settings.effective.accent,
                secondary: preview.settings.effective.accentSecondary, settingsReady: preview.settings.ready,
                scans: preview.network.backend.wifi.scanStarts, scanStops: preview.network.backend.wifi.scanStops,
                scanning: preview.network.backend.wifi.scannerEnabled,
                discovery: preview.bluetooth.backend.internal.discovering,
                discoveryChanges: preview.bluetooth.backend.internal.discoveryChanges,
                brightnessRequests: preview.brightness.backend.requests.length,
                nightRequests: preview.nightLight.backend.requests.length,
                sessionCalls: preview.sessionService.backend.calls.length,
                busy: preview.brightness.busy || preview.nightLight.busy || preview.audio.busy,
                osd: scene.osd.visible, osdScreen: scene.osd.screen ? scene.osd.screen.name : "",
                osdLoaded: scene.osdHost.loaded, toastLoaded: scene.notificationStack !== null,
                notifications: preview.notifications.entries.length,
                trayCount: preview.tray.items.values.length
            });
        }
        function open(id: string): bool { return preview.scene.coordinator.open(id, null, null); }
        function expandNetwork(): void { preview.scene.coordinator.open("network", null, null); }
        function draft(): void { preview.settings.setColor("accent", "#abcdef"); }
        function monitor(name: string): void { preview.scene.backend.focusedMonitorName = name; }
        function removeSecond(): void { preview.scene.coordinator.screens = [preview.scene.firstScreen]; }
        function restoreScreens(): void { preview.scene.coordinator.screens = [preview.scene.firstScreen, preview.scene.secondScreen]; }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
