// Test-only entrypoint: private XDG/D-Bus and PATH with fake clipboard owners.
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "preview"

ShellRoot {
    id: root
    property string generation: String(Date.now())
    LauncherBackend { id: backend }
    LauncherService { id: launcher; backend: backend }
    PanelPreviewWindow { id: window; launcher: launcher }
    LauncherIpc { coordinator: window.scene.coordinator; service: launcher }
    IpcHandler {
        target: "probe"
        function iconSnapshot(): string {
            function collect(item) {
                if (!item) return [];
                let found = [];
                if (item.objectName === "launcherApplicationIcon")
                    found.push({symbol: item.symbol, ready: item.ready,
                        visible: item.visible, width: item.width, height: item.height,
                        size: item.iconSize, padding: item.iconPadding});
                for (const child of item.children || []) found = found.concat(collect(child));
                return found;
            }
            const hostWindow = window.scene.panelHost.window;
            return JSON.stringify({icons: collect(hostWindow ? hostWindow.page : null),
                names: launcher.results.map(entry => entry.icon)});
        }
        function snapshot(): string {
            const host = window.scene.panelHost;
            return JSON.stringify({generation: root.generation, ready: backend.ready,
                applications: Array.from(backend.applications).map(app => app.id),
                results: launcher.results.map(entry => ({id: entry.id, kind: entry.kind, title: entry.title})),
                history: backend.history, clips: backend.clipboard,
                error: launcher.lastError, clipboardError: backend.clipboardError,
                active: launcher.active, loaded: host.loaded, busy: launcher.busy, searching: launcher.searching,
                activeId: window.scene.coordinator.activeId, mode: launcher.mode,
                text: launcher.text, commandInput: launcher.commandInput,
                previewId: launcher.previewId, previewText: launcher.previewText,
                previewImage: launcher.previewImage.length > 0,
                created: window.scene.createdCount, destroyed: window.scene.destroyedCount,
                focus: host.window && host.window.Window.window && host.window.Window.window.activeFocusItem
                    ? host.window.Window.window.activeFocusItem.objectName : ""});
        }
        function edit(value: string): void { launcher.edit(value); }
        function select(index: int): void {
            const page = window.scene.panelHost.window.page;
            page.selectedIndex = index;
            page.rememberSelection();
        }
        function previewSnapshot(): string {
            function find(item, name) {
                if (!item) return null;
                if (item.objectName === name) return item;
                for (const child of item.children || []) {
                    const result = find(child, name);
                    if (result) return result;
                }
                return null;
            }
            const surface = window.scene.panelHost.window;
            const frame = find(surface, "launcherPreview"), image = find(frame, "launcherPreviewImage");
            return JSON.stringify(frame ? {width: frame.width, height: frame.height,
                x: frame.mapToItem(surface, 0, 0).x, y: frame.mapToItem(surface, 0, 0).y,
                imageReady: image.status === Image.Ready,
                paintedWidth: image.paintedWidth, paintedHeight: image.paintedHeight} : {});
        }
        function activate(index: int): bool { return launcher.activate(launcher.results[index]); }
        function reloadShell(hard: bool): void { Quickshell.reload(hard); }
    }
}
