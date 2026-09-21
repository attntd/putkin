import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var controller
    readonly property IpcHandler handler: IpcHandler {
        target: "bar"
        function focus(): string { return root.controller.focusBar(); }
        function close(): void { root.controller.close(); }
        function status(): string {
            const service = root.controller.service;
            const rows = [];
            for (let index = 0; index < service.workspaces.count; ++index) {
                const row = service.workspaces.get(index);
                rows.push({id: row.workspaceId, visibleOn: row.visibleOn});
            }
            return JSON.stringify({available: service.available, monitors: service.monitors,
                focusedMonitor: service.focusedMonitorName, workspaces: rows,
                busy: service.busy, error: service.lastError});
        }
    }
}
