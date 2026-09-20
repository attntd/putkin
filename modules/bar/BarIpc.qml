import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var controller
    readonly property IpcHandler handler: IpcHandler {
        target: "bar"
        function focus(): string { return root.controller.focusBar(); }
        function close(): void { root.controller.close(); }
    }
}
