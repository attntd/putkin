import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "preview"

ShellRoot {
    id: root
    property var backendErrors: []
    BluetoothBackend { id: backend }
    BluetoothService { id: bluetooth; backend: backend; actionTimeout: 1200; radioTimeout: 900 }
    PanelPreviewWindow { id: preview; bluetooth: bluetooth }
    readonly property double generation: Date.now()
    function recordBackendError(): void { if (backend.lastError) backendErrors = backendErrors.concat([backend.lastError]); }
    Connections { target: backend; function onLastErrorChanged(): void { root.recordBackendError(); } }
    Component.onCompleted: recordBackendError()
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({
                available: bluetooth.available, status: bluetooth.statusText,
                selected: bluetooth.adapter ? bluetooth.adapter.adapterId : "",
                radio: bluetooth.radioEnabled, blocked: bluetooth.blocked, busy: bluetooth.busy,
                error: bluetooth.lastError, backendError: backend.lastError, backendErrors: root.backendErrors,
                managerError: backend.managerError, watcherPid: backend.watcherProcessId, actionPid: backend.action.processId,
                adapters: bluetooth.adapters.map(a => ({id: a.adapterId, enabled: a.enabled, discovering: a.discovering})),
                devices: bluetooth.devices.map(d => ({name: d.name, path: d.dbusPath, connected: d.connected,
                    battery: d.battery, batteryAvailable: d.batteryAvailable, paired: d.paired})),
                loaded: preview.scene.panelHost.loaded, created: preview.scene.createdCount,
                destroyed: preview.scene.destroyedCount, generation: root.generation
            });
        }
        function expand(): void { preview.scene.panelHost.window.page.bluetoothSection.expanded = true; }
        function activate(name: string): void { bluetooth.activate(bluetooth.devices.find(d => d.name === name)); }
        function select(id: string): void { bluetooth.selectAdapter(bluetooth.adapters.find(a => a.adapterId === id)); }
        function radio(value: bool): void { bluetooth.setEnabled(value); }
        function manager(): void { bluetooth.openManager(); }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
