import QtQuick
import Quickshell.Io

QtObject {
    id: root
    // Tests inject an absolute fake executable. Production uses brightnessctl.
    property string executable: "brightnessctl"
    property int commandTimeout: 1500
    property int activeId: -1
    property bool started: false
    property bool timedOut: false
    readonly property var localeEnvironment: ({ LC_ALL: "C", LANG: "C" })
    readonly property bool busy: activeId >= 0
    readonly property var processId: process.processId
    signal completed(int requestId, var result)

    function run(requestId: int, arguments: var): bool {
        if (busy) return false;
        activeId = requestId;
        started = false;
        timedOut = false;
        process.command = [executable].concat(arguments);
        deadline.restart();
        process.running = true;
        return true;
    }
    function finish(code: int, output: string, error: string, failure: string): void {
        if (activeId < 0) return;
        const requestId = activeId;
        const result = { code: code, output: output, error: error, failure: timedOut ? "timeout" : failure };
        deadline.stop();
        terminate.stop();
        activeId = -1;
        // Do not restart Process from inside its native completion callback.
        Qt.callLater(() => root.completed(requestId, result));
    }
    readonly property Process process: Process {
        environment: root.localeEnvironment
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onStarted: {
            root.started = true;
            if (root.timedOut) { running = false; root.terminate.restart(); }
        }
        // 0.3.1 emits runningChanged, but no exited, on FailedToStart.
        onRunningChanged: {
            if (!running && root.busy && !root.started)
                root.finish(127, "", "", "start");
        }
    }
    readonly property Timer deadline: Timer {
        interval: root.commandTimeout
        onTriggered: {
            root.timedOut = true;
            if (root.process.running) {
                root.process.running = false; // SIGTERM, including a starting child.
                root.terminate.restart();
            } else root.finish(124, "", "", "timeout");
        }
    }
    readonly property Timer terminate: Timer {
        interval: 150
        onTriggered: { if (root.process.running && root.process.processId > 0) root.process.signal(9); }
    }
    // ExitStatus is a native enum absent from 0.3.1's qmltypes. Connect the
    // runtime signal explicitly; integration tests exercise both exit paths.
    Component.onCompleted: process.exited.connect((exitCode, exitStatus) => root.finish(exitCode, output.text, errors.text, exitStatus === 0 ? "" : "crash"))
    Component.onDestruction: { if (process.running && process.processId > 0) process.signal(9); }
}
