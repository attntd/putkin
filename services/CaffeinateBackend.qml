import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string helperPath: Quickshell.shellPath("services/caffeinate_backend.py")
    property var helperEnvironment: ({})
    property string mode: "off"
    property string requestedMode: "off"
    property string errorText: ""
    property bool busy: false
    property bool stopping: false
    property bool failed: false
    readonly property bool available: true
    readonly property int processId: worker.processId || 0
    function fail(message: string): void {
        errorText = message;
        failed = true;
        mode = "off";
        deadline.stop();
        if (worker.running && worker.processId > 0) worker.signal(9);
        else busy = false;
    }
    function request(value: string): bool {
        if (busy || ["off", "presentation", "background"].indexOf(value) < 0) return false;
        if (value === mode) return true;
        busy = true;
        failed = false;
        errorText = "";
        requestedMode = value;
        deadline.start();
        if (worker.running) worker.write(JSON.stringify({mode: value}) + "\n");
        else worker.running = true;
        return true;
    }
    function receive(line: string): void {
        let value;
        try { value = JSON.parse(line); }
        catch (_) { fail(qsTr("Nieprawidłowa odpowiedź adaptera Caffeinate.")); return; }
        if (!value || ["off", "presentation", "background"].indexOf(value.mode) < 0 || typeof value.error !== "string") {
            fail(qsTr("Nieprawidłowa odpowiedź adaptera Caffeinate.")); return;
        }
        if (failed) return;
        mode = value.mode;
        errorText = value.error;
        deadline.stop();
        // The off helper is exiting. Do not reuse its pipe for a new request.
        busy = mode === "off";
    }
    readonly property Process worker: Process {
        command: ["python3", "-B", root.helperPath, root.requestedMode]
        environment: root.helperEnvironment
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: SplitParser { onRead: data => { console.error("Caffeinate: " + data); root.fail(qsTr("Adapter Caffeinate nie działa.")); } }
    }
    // Quickshell 0.3.1 omits ExitStatus in qmltypes; use the same actual
    // signal connection as the other Process adapters, verified natively.
    Component.onCompleted: worker.exited.connect(() => {
            if (!root.stopping && (root.mode !== "off" || (root.busy && !root.errorText && root.requestedMode !== "off")))
                root.errorText = qsTr("Utracono blokadę usypiania: adapter Caffeinate zakończył pracę.");
            root.mode = "off";
            root.busy = false;
            root.deadline.stop();
    })
    readonly property Timer deadline: Timer {
        interval: 5000
        onTriggered: root.fail(qsTr("Przekroczono czas zmiany Caffeinate; blokada została zwolniona."))
    }
    Component.onDestruction: {
        stopping = true;
        if (worker.running && worker.processId > 0) worker.signal(9);
    }
}
