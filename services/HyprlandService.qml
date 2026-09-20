import QtQml
import Quickshell.Hyprland
import Quickshell.Io

WorkspaceService {
    backend: QtObject {
        readonly property bool connected: connection.connected
        readonly property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        readonly property var activeWindow: Hyprland.activeToplevel
        readonly property var windows: Hyprland.toplevels.values
        readonly property var monitors: Hyprland.monitors.values.map(monitor => ({
            name: monitor.name,
            activeId: monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
        }))
        readonly property var workspaces: Hyprland.workspaces.values.map(workspace => ({
            id: workspace.id,
            occupied: workspace.toplevels.values.length > 0,
            urgent: workspace.urgent
        }))

        function focusMonitor(name: string): void {
            // Only a name already present in the native monitor model is accepted.
            const monitor = Hyprland.monitors.values.find(item => item.name === name);
            if (!monitor)
                return;
            Hyprland.dispatch(Hyprland.usingLua
                ? 'hl.dsp.focus({ monitor = "' + monitor.id + '" })'
                : "focusmonitor " + monitor.id);
        }

        function activateWorkspace(id: int): void {
            Hyprland.dispatch(Hyprland.usingLua
                ? 'hl.dsp.focus({ workspace = "' + id + '", on_current_monitor = true })'
                : "focusworkspaceoncurrentmonitor " + id);
        }

        function focusWindow(window: var): void {
            if (!window || windows.indexOf(window) < 0 || !/^(?:0x)?[0-9a-fA-F]{1,16}$/.test(window.address)) return;
            const selector = "address:0x" + window.address.replace(/^0x/, "");
            Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ window = "' + selector + '" })' : "focuswindow " + selector);
        }
        function refreshWindows(): void { Hyprland.refreshToplevels(); }

        function moveWindow(window: var, id: int): void {
            // Address only the captured live native object, never the current
            // focus after a panel has taken the keyboard. Pattern from putpuccin.
            if (!window || windows.indexOf(window) < 0 || id < 1 || id > 10) return;
            const address = window.address.replace(/^0x/, "").replace(/^0+/, "");
            if (!/^[0-9a-fA-F]{1,16}$/.test(address)) return;
            const selector = "address:0x" + address;
            Hyprland.dispatch(Hyprland.usingLua
                ? 'hl.dsp.window.move({ workspace = "' + id + '", follow = false, window = "' + selector + '" })'
                : "movetoworkspacesilent " + id + "," + selector);
        }

        // 0.3.1 does not expose its IPC connection state or clear stale models.
        // One shared, passive socket detects EOF. Native models remain the only
        // source of workspace data. No polling and no reconnect to stale state.
        readonly property Socket connection: Socket {
            path: Hyprland.eventSocketPath
            connected: path.length > 0
            parser: SplitParser { onRead: {} }
        }
    }
}
