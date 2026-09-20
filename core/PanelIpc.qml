import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var coordinator
    readonly property IpcHandler handler: IpcHandler {
        target: "ui"
        function openNetwork(): string { return root.coordinator.open("network", null, null) ? "ok" : root.coordinator.lastError; }
        function openBluetooth(): string { return root.coordinator.open("bluetooth", null, null) ? "ok" : root.coordinator.lastError; }
        function openNotifications(): string { return root.coordinator.open("notifications", null, null) ? "ok" : root.coordinator.lastError; }
        function openAudio(): string {
            return root.coordinator.open("audio", null, null) ? "ok" : root.coordinator.lastError;
        }
        function toggleAudio(): string {
            return root.coordinator.toggle("audio", null, null) ? "ok" : root.coordinator.lastError;
        }
        function openBattery(): string {
            return root.coordinator.open("battery", null, null) ? "ok" : root.coordinator.lastError;
        }
        function toggleBattery(): string {
            return root.coordinator.toggle("battery", null, null) ? "ok" : root.coordinator.lastError;
        }
        function openQuickSettings(): string {
            return root.coordinator.open("quickSettings", null, null) ? "ok" : root.coordinator.lastError;
        }
        function toggleQuickSettings(): string {
            return root.coordinator.toggle("quickSettings", null, null) ? "ok" : root.coordinator.lastError;
        }
        function openSettings(): string {
            return root.coordinator.open("settings", null, null) ? "ok" : root.coordinator.lastError;
        }
        function closePanels(): void { root.coordinator.close(true); }
    }
}
