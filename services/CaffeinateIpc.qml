import QtQuick
import Quickshell.Io

QtObject {
    id: root
    required property var service
    readonly property IpcHandler handler: IpcHandler {
        target: "caffeinate"
        function status(): string {
            return JSON.stringify({active: root.service.enabled, mode: root.service.mode, busy: root.service.busy,
                preventDisplaySleep: root.service.mode === "presentation", preventLock: root.service.mode === "presentation",
                preventSleep: root.service.enabled, error: root.service.lastError});
        }
        function setEnabled(enabled: bool): string { return root.service.setEnabled(enabled) ? "accepted" : "rejected"; }
        function setMode(mode: string): string { return root.service.setMode(mode) ? "accepted" : "rejected"; }
    }
}
