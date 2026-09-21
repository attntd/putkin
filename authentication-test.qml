pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "modules/authentication"

ShellRoot {
    id: root
    property bool blocked: false
    property string generation: String(Date.now())
    AuthenticationService { id: service; blocked: root.blocked }
    AuthenticationBackend {
        id: backend
        service: service
        pamConfigPath: Quickshell.env("PUTKIN_AUTHENTICATION_TEST") + "/polkit-policy"
    }
    HyprlandService { id: monitor }
    QtObject { id: panels; function close(_restore) {} }
    QtObject { id: bar; function close() {} }
    AuthenticationHost { id: host; service: service; screens: Quickshell.screens; monitorService: monitor; panels: panels; barFocus: bar }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const r = service.current;
            return JSON.stringify({registered: backend.registered, active: service.active, count: service.count,
                title: r ? r.title : "", mode: r ? r.mode : "", input: r ? r.responseRequired : false,
                fingerprint: r ? r.fingerprintState : "hidden", error: r ? r.errorText : "",
                progress: r ? r.fingerprintProgress : 0, countdown: r ? r.fingerprintCountdown : false,
                fingerprintTimeoutMs: backend.fingerprintTimeoutMs,
                channels: backend.channels, generation: root.generation, screen: host.selectedScreenName});
        }
        function block(value: bool): void { root.blocked = value; }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
