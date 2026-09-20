// Only scripts/test-settings-integration: private XDG/D-Bus, mock desktop.
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "preview"

ShellRoot {
    id: root
    property string generation: String(Date.now())
    property int nativeSaves: 0
    property int nativeFailures: 0
    property int reads: 0
    PanelPreviewWindow { id: window }
    Connections {
        target: window.settings.storage.file
        function onSaved(): void { root.nativeSaves++; }
        function onSaveFailed(): void { root.nativeFailures++; }
        function onLoaded(): void { root.reads++; }
        function onLoadFailed(): void { root.reads++; }
    }
    function findControl(item: Item, name: string): var {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const found = findControl(child, name);
            if (found) return found;
        }
        return null;
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const s = window.settings, scene = window.scene, host = scene.panelHost;
            const surface = host.window;
            const field = root.findControl(surface, "accentField");
            return JSON.stringify({
                generation: root.generation, ready: s.ready, persisted: s.persisted, effective: s.effective,
                draft: s.draft, editing: s.editing, saving: s.saving, conflict: s.conflict,
                readProblem: s.readProblem, saveProblem: s.saveProblem, notice: s.notice, canSave: s.canSave,
                token: s.diskToken, phase: s.storage.phase, nativeSaves: root.nativeSaves,
                nativeFailures: root.nativeFailures, reads: root.reads, path: s.storage.path,
                activeId: scene.coordinator.activeId, loaded: host.loaded,
                created: scene.createdCount, destroyed: scene.destroyedCount,
                focus: surface && surface.Window.window && surface.Window.window.activeFocusItem
                    ? surface.Window.window.activeFocusItem.objectName : "",
                cursor: field ? field.cursorPosition : -1, fieldText: field ? field.text : ""
            });
        }
        function edit(key: string, value: string): void { window.settings.setColor(key, value); }
        function save(): string {
            const accepted = window.settings.save();
            return JSON.stringify({accepted: accepted, saving: window.settings.saving,
                notice: window.settings.notice, persisted: window.settings.persisted});
        }
        function reset(): void { window.settings.resetDraft(); }
        function useLatest(): void { window.settings.useLatest(); }
        function refresh(): void { window.settings.storage.refresh(); }
        function watchFile(enabled: bool): void {
            window.settings.storage.file.watchChanges = enabled;
            window.settings.storage.parentWatch.watchChanges = enabled;
        }
        function saveAndClose(): void {
            window.settings.save();
            window.scene.coordinator.close(false);
        }
        function focusField(): void {
            const field = root.findControl(window.scene.panelHost.window, "accentField");
            if (field) field.forceActiveFocus(Qt.TabFocusReason);
        }
        function removeScreen(): void { window.scene.coordinator.screens = [window.scene.secondScreen]; }
        function reloadShell(hard: bool): void { Quickshell.reload(hard); }
    }
}
