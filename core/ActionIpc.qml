import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var controller
    readonly property IpcHandler handler: IpcHandler {
        target: "actions"
        function invoke(action: string): string {
            const service = root.controller.hyprland;
            return root.controller.invoke(action, service.activeWindow, service.focusedMonitorName) ? "accepted" : root.controller.lastError;
        }
        function status(): string {
            const keyboard = root.controller.launcher.keyboard;
            return JSON.stringify({ready: keyboard.ready, busy: keyboard.backend.current !== null || keyboard.backend.queue.length > 0,
                applied: keyboard.backend.hasApplied, error: keyboard.readProblem || keyboard.backend.lastError,
                shortcuts: keyboard.persisted.filter(row => row.shortcut).length, commands: keyboard.persisted.filter(row => row.command).length});
        }
    }
}
