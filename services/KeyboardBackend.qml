import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: root
    property string lastError: ""
    property bool hasApplied: false
    property string shellPath: Quickshell.shellDir + "/shell.qml"
    property var queue: []
    property var current: null
    property bool expired: false
    signal checked(int generation, string error)
    signal reloaded()
    function enqueue(operation: string, bindings: var, generation: int): void {
        // Coalesce pending refreshes; preserve an editor's validation request.
        queue = queue.filter(item => item.operation !== operation).concat([{operation: operation, bindings: bindings, generation: generation,
            shell: shellPath}]);
        Qt.callLater(pump);
    }
    function apply(bindings: var): void { enqueue("apply", bindings, 0); }
    function check(generation: int, bindings: var): void { enqueue("check", bindings, generation); }
    function pump(): void {
        if (current || !queue.length) return;
        current = queue[0]; queue = queue.slice(1); expired = false;
        worker.stdinEnabled = true; worker.running = true; deadline.restart();
    }
    function finish(code: int, status: int): void {
        if (!current) return;
            root.deadline.stop();
            let error = "";
            try { error = JSON.parse(output.text).error; } catch (_) { error = qsTr("Adapter skrótów nie odpowiedział."); }
            if (root.expired) error = qsTr("Upłynął czas zmiany skrótów.");
            else if ((code !== 0 || status !== 0) && !error) error = qsTr("Błąd adaptera skrótów.");
            const operation = root.current.operation;
            const generation = root.current.generation;
            root.current = null;
            if (operation === "check") root.checked(generation, error);
            else { root.lastError = error; root.hasApplied = !error; }
            Qt.callLater(root.pump);
    }
    readonly property Process worker: Process {
        command: ["python3", Quickshell.shellDir + "/services/keyboard.py"]
        stdinEnabled: true
        stdout: StdioCollector { id: output }
        stderr: StdioCollector {}
        onStarted: { write(JSON.stringify(root.current)); stdinEnabled = false; }

    }
    Component.onCompleted: worker.exited.connect((code, status) => root.finish(code, status))
    readonly property Timer deadline: Timer { interval: 20000; onTriggered: { root.expired = true; root.worker.running = false; } }
    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void { if (event.name === "configreloaded") root.reloaded(); }
    }
}
