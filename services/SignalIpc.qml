import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var service
    required property var coordinator
    property bool blocked: false
    readonly property IpcHandler handler: IpcHandler {
        target: "signal"
        // Operational diagnostics deliberately omit account IDs, QR and content.
        function status(): string {
            return JSON.stringify({state: root.service.state, accountState: root.service.accountState,
                schemaVersion: root.service.schemaVersion, cliVersion: root.service.cliVersion,
                errorCode: root.service.errorCode, linkError: root.service.linkError,
                eventErrorLocation: root.service.backend.eventErrorLocation || "",
                qrVisible: root.service.qrModules.length > 0,
                processId: root.service.backend.processId});
        }
        function openSettings(): bool {
            if (root.blocked) return false;
            root.coordinator.settingsSection = "signal";
            root.coordinator.settingsRequest++;
            return root.coordinator.open("settings", null, null);
        }
        function pair(): bool {
            if (root.blocked || root.service.accountState === "linked" || !openSettings()) return false;
            return root.service.startLink(root.service.configuration.deviceName || "Putkin") !== "";
        }
    }
}
