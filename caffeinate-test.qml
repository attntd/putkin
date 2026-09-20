import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    CaffeinateBackend { id: backend }
    CaffeinateService { id: service; backend: backend }
    CaffeinateIpc { service: service }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({mode: service.mode, busy: service.busy, error: service.lastError, pid: backend.processId});
        }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
