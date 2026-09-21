import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: root
    readonly property var commands: ipc.handler
    QtObject {
        id: service
        property string state: "idle"
        property string accountState: "unlinked"
        property int schemaVersion: 7
        property string cliVersion: "0.14.8"
        property string errorCode: ""
        property string linkError: ""
        property var qrModules: ["private QR data"]
        property string accountId: "private account"
        property var configuration: ({deviceName: "Putkin"})
        property QtObject backend: QtObject { property int processId: 123 }
        property int links: 0
        function startLink(name: string): string { links++; return "request-id"; }
    }
    QtObject {
        id: panels
        property string settingsSection: "appearance"
        property int settingsRequest: 0
        property string active: ""
        function open(name: string, screen: var, invoker: var): bool { active = name; return true; }
    }
    SignalIpc { id: ipc; service: service; coordinator: panels }
    IpcHandler {
        target: "releaseTest"
        function check(): string {
            const raw = root.commands.status();
            if (raw.indexOf("private") >= 0 || !JSON.parse(raw).qrVisible) return "FAIL: private status";
            if (!root.commands.pair() || service.links !== 1 || panels.settingsSection !== "signal" || panels.active !== "settings") return "FAIL: pairing";
            const revision = panels.settingsRequest;
            if (!root.commands.openSettings() || panels.settingsRequest !== revision + 1) return "FAIL: repeated settings";
            ipc.blocked = true;
            if (root.commands.pair() || root.commands.openSettings() || service.links !== 1) return "FAIL: blocked";
            ipc.blocked = false;
            service.accountState = "linked";
            if (root.commands.pair() || service.links !== 1 || !root.commands.openSettings()) return "FAIL: linked";
            return "PASS";
        }
    }
}
