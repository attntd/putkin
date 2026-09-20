import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var coordinator
    required property var service
    function openMode(mode: string): string {
        if (!coordinator.open("launcher", null, null)) return coordinator.lastError;
        service.startMode(mode);
        return "ok";
    }
    readonly property IpcHandler handler: IpcHandler {
        target: "launcher"
        function toggle(): string { return root.coordinator.toggle("launcher", null, null) ? "ok" : root.coordinator.lastError; }
        function open(): string { return root.coordinator.open("launcher", null, null) ? "ok" : root.coordinator.lastError; }
        function openClipboard(): string { return root.openMode("clipboard"); }
        function openCommands(): string { return root.openMode("commands"); }
        function close(): void { if (root.coordinator.activeId === "launcher") root.coordinator.close(true); }
    }
}
