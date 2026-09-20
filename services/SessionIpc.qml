import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var service
    required property var coordinator
    property var lockService: null
    property var idleService: null
    readonly property IpcHandler handler: IpcHandler {
        target: "session"
        function openPower(): string {
            return root.coordinator.open("power", null, null) ? "ok" : root.coordinator.lastError;
        }
        function lock(): string { return root.service.request("lock") ? "accepted" : root.service.busy ? "busy" : root.service.lastError; }
        function status(): string {
            return JSON.stringify({ busy: root.service.busy, phase: root.service.phase, error: root.service.lastError,
                result: root.service.resultText, capabilities: root.service.capabilities,
                lock: root.lockService ? { locked: root.lockService.locked, secure: root.lockService.secure } : null,
                idle: root.idleService ? { ready: root.service.backend.idleReady,
                    inhibited: root.idleService.idleBlocked, sleepInhibited: root.idleService.sleepBlocked,
                    dimmed: root.idleService.dimmed, displaysOff: root.idleService.displaysOff,
                    error: root.idleService.lastError } : null });
        }
    }
}
