import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var service
    required property var controller
    readonly property IpcHandler handler: IpcHandler {
        target: "notifications"
        function focus(): string { return root.controller.focus(); }
        function leave(): void { root.controller.closeCenter(); }
        function setDnd(enabled: bool): bool { if (!root.service.available) return false; root.service.dnd = enabled; return true; }
        function toggleDnd(): bool { if (!root.service.available) return false; root.service.dnd = !root.service.dnd; return root.service.dnd; }
    }
}
