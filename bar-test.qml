// Test-only entrypoint: the wrapper supplies private fake Hyprland sockets.
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "preview"
import "modules/bar"

ShellRoot {
    id: root
    property int commandsCompleted: 0
    HyprlandService { id: service }
    MockLauncherBackend { id: launcherBackend }
    LauncherService {
        id: launcher
        backend: launcherBackend
        workspaceService: service
        onActivated: { root.commandsCompleted++; setActive(false); }
    }
    BarFocus {
        id: controller
        service: service
        screenNames: service.monitors.map(monitor => monitor.name)
    }
    BarIpc { controller: controller }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const rows = [];
            for (let i = 0; i < service.workspaces.count; ++i) {
                const row = service.workspaces.get(i);
                rows.push({ id: row.workspaceId, occupied: row.occupied, urgent: row.urgent, visibleOn: row.visibleOn });
            }
            return JSON.stringify({ available: service.available, monitors: service.monitors,
                focusedMonitor: service.focusedMonitorName, navigationMonitor: controller.screenName,
                rows: rows, busy: service.busy, error: service.lastError,
                activeWindow: service.activeWindow ? service.activeWindow.address : "",
                windows: service.windows.map(window => ({address: window.address, workspace: window.workspace ? window.workspace.id : -1})),
                launcherActive: launcher.active, launcherBusy: launcher.busy, launcherError: launcher.lastError,
                commandsCompleted: root.commandsCompleted });
        }
        function activate(id: int, monitor: string): bool { return service.activate(id, monitor); }
        function openLauncher(): void { launcher.setActive(false); launcher.setActive(true); }
        function command(text: string): bool { launcher.edit(text); return launcher.activate(launcher.results[0]); }
    }
}
