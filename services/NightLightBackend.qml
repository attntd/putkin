import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string helperPath: Quickshell.shellPath("services/night_light.py")
    property int commandTimeout: 5000
    property int activeId: -1
    property bool started: false
    property bool timedOut: false
    readonly property bool busy: activeId >= 0
    readonly property var localeEnvironment: ({ LC_ALL: "C", LANG: "C", NO_COLOR: "1" })
    readonly property var processId: process.processId
    signal completed(int requestId, var result)

    function run(requestId: int, arguments: var): bool {
        if (busy) return false;
        activeId = requestId; started = false; timedOut = false;
        process.command = ["python3", helperPath].concat(arguments);
        deadline.restart();
        process.running = true;
        return true;
    }
    function finish(code: int, failure: string): void {
        if (!busy) return;
        const id = activeId;
        let result = { sample: null, error: timedOut ? "timeout" : failure || (code ? "helper" : "") };
        if (!result.error) {
            try { result = JSON.parse(output.text); }
            catch (_) { result = { sample: null, error: "protocol" }; }
        }
        deadline.stop(); terminate.stop(); activeId = -1;
        Qt.callLater(() => root.completed(id, result));
    }
    readonly property Process process: Process {
        environment: root.localeEnvironment
        stdout: StdioCollector { id: output }
        onStarted: {
            root.started = true;
            if (root.timedOut) { running = false; root.terminate.restart(); }
        }
        onRunningChanged: { if (!running && root.busy && !root.started) root.finish(127, "helper"); }
    }
    readonly property Timer deadline: Timer {
        interval: root.commandTimeout
        onTriggered: {
            root.timedOut = true;
            if (root.process.running) { root.process.running = false; root.terminate.restart(); }
            else root.finish(124, "timeout");
        }
    }
    readonly property Timer terminate: Timer {
        interval: 150
        onTriggered: { if (root.process.running && root.process.processId > 0) root.process.signal(9); }
    }
    // ExitStatus is absent from 0.3.1 qmltypes; exercise the real signal in integration.
    Component.onCompleted: process.exited.connect((code, status) => root.finish(code, status === 0 ? "" : "helper"))
    Component.onDestruction: { if (process.running && process.processId > 0) process.signal(9); }
}
