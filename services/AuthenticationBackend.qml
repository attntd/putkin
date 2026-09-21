import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Hyprland
import "AuthenticationMessages.js" as Messages

QtObject {
    id: root
    required property var service
    property int channels: 0
    property string pamConfigPath: "/etc/pam.d/polkit-1"
    readonly property int fingerprintTimeoutMs: Messages.fingerprintTimeout(pamConfig.text())
    readonly property FileView pamConfig: FileView {
        path: root.pamConfigPath
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property bool registered: agent.isRegistered
    readonly property bool usingLua: Hyprland.usingLua
    // 0.3.1 qmltypes refers to AuthFlow without its C++ namespace. Reading
    // through a variant preserves the real runtime object without hiding imports.
    readonly property var nativeAgent: agent
    readonly property PolkitAgent agent: PolkitAgent {
        path: "/org/putkin/Polkit"
        onFlowChanged: {
            if (!root.nativeAgent.flow) return;
            const request = root.polkitFactory.createObject(root, {
                flow: root.nativeAgent.flow, fingerprintTimeoutMs: root.fingerprintTimeoutMs
            }) as PolkitRequest;
            // AuthFlow starts PAM immediately. Never leave a scan running
            // behind another dialog, where its purpose would be invisible.
            if (root.service.count > 0) { request.cancel(); request.release(); }
            else root.service.enqueue(request);
        }
    }
    readonly property Component polkitFactory: Component { PolkitRequest {} }
    readonly property Component socketFactory: Component { AuthenticationSocket {} }
    readonly property IpcHandler ipc: IpcHandler {
        target: "authentication"
        function request(path: string): string {
            const prefix = Quickshell.env("XDG_RUNTIME_DIR") + "/putkin-auth-";
            if (root.service.blocked || root.channels >= 8 || root.service.count >= 8
                    || !path.startsWith(prefix) || !/^[a-zA-Z0-9_-]+\/socket$/.test(path.slice(prefix.length)))
                return JSON.stringify({accepted: false});
            const request = root.socketFactory.createObject(root, {socketPath: path, service: root.service}) as AuthenticationSocket;
            root.channels++;
            request.released.connect(() => root.channels--);
            return JSON.stringify({accepted: true, pid: Quickshell.processId});
        }
        function status(): string { return JSON.stringify({registered: root.registered, count: root.service.count,
            blocked: root.service.blocked, fingerprintTimeoutMs: root.fingerprintTimeoutMs}); }
    }
    function configure(): void {
        if (usingLua) Hyprland.dispatch('function() hl.layer_rule({name="putkin-authentication",match={namespace="^putkin-authentication$"},no_anim=true,blur=false,dim_around=false}) end');
    }
    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void { if (event.name === "configreloaded") root.configure(); }
    }
    onUsingLuaChanged: configure()
    Component.onCompleted: configure()
}
