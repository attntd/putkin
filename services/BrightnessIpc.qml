import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var brightness
    readonly property IpcHandler handler: IpcHandler {
        target: "brightness"
        function setPercent(percent: real): string { return root.brightness.setPercent(percent, "") ? "accepted" : root.brightness.lastError; }
        function change(points: real): string { return root.brightness.change(points, "") ? "accepted" : root.brightness.lastError; }
        function refresh(): string { root.brightness.refresh(); return "accepted"; }
        function status(): string {
            return JSON.stringify({ available: root.brightness.available, device: root.brightness.device,
                percent: root.brightness.available ? root.brightness.percent : null,
                busy: root.brightness.busy, error: root.brightness.lastError, diagnostic: root.brightness.diagnostic });
        }
    }
}
