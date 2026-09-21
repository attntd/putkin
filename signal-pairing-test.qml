pragma ComponentBehavior: Bound

// Only the isolated S03 runner: real settings window and Signal bridge, fake CLI.
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "preview"
import "services"
import "modules/settings"

ShellRoot {
    id: root
    property bool captured: false
    readonly property var testHost: host
    readonly property var testSettings: settings
    SignalBackend {
        id: backend
        helperArguments: ["--test-scenario", Quickshell.env("PUTKIN_SIGNAL_TEST_SCENARIO")]
    }
    SignalService { id: service; backend: backend }
    MockSettingsFile { id: file }
    Settings { id: settings; storage: file }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    QtObject {
        id: focusMock
        property string screenName: ""
        property string focusedMonitorName: ""
        signal entered(string name)
        function close(): void {}
        function resume(_name: string, _invoker: var): void {}
    }
    PanelCoordinator { id: panels; screens: Quickshell.screens; monitorService: focusMock; barFocus: focusMock; settings: root.testSettings }
    PanelHost { id: host; coordinator: panels; loader: windowLoader; signalService: service }
    LazyLoader { id: windowLoader; component: SettingsWindow { host: root.testHost } }
    function surface(): var {
        if (!host.window) return null;
        return host.window.contentItem.children.find(item => item.objectName === "settingsSurface") || null;
    }
    function findControl(item: Item, name: string): var {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const result = findControl(child, name);
            if (result) return result;
        }
        return null;
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({state: service.state, account: service.accountState, accountId: service.accountId,
                pid: backend.processId, generation: backend.generation, error: service.errorCode,
                qrSize: service.qrModules.length, linking: service.linkAttempt !== "", reconciling: service.reconciling,
                loaded: host.loaded, pageReady: root.surface() !== null && root.surface().page !== null,
                captured: root.captured, status: service.statusText});
        }
        function open(): void { panels.open("settings", null, null); }
        function section(name: string): void { if (root.surface() && root.surface().page) root.surface().page.section = name; }
        function activate(name: string): bool {
            const button = root.findControl(root.surface(), name);
            if (!button || !button.enabled || !button.visible) return false;
            button.click();
            return true;
        }
        function close(): void { panels.close(false); }
        function retry(): void { service.refreshAccount(); }
        function reload(): void { Quickshell.reload(true); }
        function capture(path: string): bool {
            // Never save a QR/attempt, even a synthetic one, in review artifacts.
            if (!root.surface() || service.qrModules.length || service.linkAttempt || service.reconciling) return false;
            root.captured = false;
            return root.surface().grabToImage(result => { root.captured = result.saveToFile(path); });
        }
        function quit(): void { Qt.quit(); }
    }
}
