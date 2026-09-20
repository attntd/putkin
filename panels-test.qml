// Only the isolated test wrapper uses this entrypoint and its probe handler.
import QtQuick
import Quickshell
import Quickshell.Io
import "preview"

ShellRoot {
    PanelPreviewWindow { id: window }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const scene = window.scene;
            const host = scene.panelHost;
            const surface = host.window;
            return JSON.stringify({
                activeId: scene.coordinator.activeId, screen: scene.coordinator.screenName,
                loaded: host.loaded, interactive: host.interactive,
                created: scene.createdCount, destroyed: scene.destroyedCount,
                focus: surface && surface.Window.window && surface.Window.window.activeFocusItem
                    ? surface.Window.window.activeFocusItem.objectName : "",
                barFocus: scene.barController.screenName,
                pageEnabled: surface ? surface.enabled : false
            });
        }
        function selectMonitor(name: string): void { window.scene.backend.focusedMonitorName = name; }
        function removeSecond(): void { window.scene.coordinator.screens = [window.scene.firstScreen]; }
        function clearScreens(): void { window.scene.coordinator.screens = []; }
        function restoreScreens(): void {
            window.scene.coordinator.screens = [window.scene.firstScreen, window.scene.secondScreen];
        }
        function openUnknown(): string {
            return window.scene.coordinator.open("not-implemented", null, null) ? "ok" : window.scene.coordinator.lastError;
        }
        function reopenImmediately(): void {
            window.scene.coordinator.close(false);
            window.scene.coordinator.open("quickSettings", null, null);
        }
    }
}
