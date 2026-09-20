import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string executable: "python3"
    property string helperPath: decodeURIComponent(Qt.resolvedUrl("launcher_backend.py").toString().replace(/^file:\/\//, ""))
    readonly property var applications: DesktopEntries.applications.values
    property var clipboard: []
    property var history: []
    property string clipboardError: ""
    property string historyError: ""
    property string lastError: ""
    property bool ready: false
    property bool visible: false
    signal searched(int revision, var entries, string error)
    signal activated(int request, string error)
    signal previewed(int revision, string key, string text, string image, string error)



    function send(message: var): bool {
        if (!ready) return false;
        process.write(JSON.stringify(message) + "\n");
        return true;
    }
    function setVisible(value: bool): void {
        visible = value;
        send({op: "visible", value: value});
    }
    function search(revision: int, query: string): bool {
        return send({op: "search", revision: revision, query: query});
    }
    function preview(revision: int, key: string): bool {
        return send({op: "preview", revision: revision, key: key});
    }
    function activate(request: int, entry: var): bool {
        const app = entry.application;
        return send({op: "activate", request: request, entry: {kind: entry.kind, id: entry.id},
            command: app ? Array.from(app.command) : [], directory: app ? app.workingDirectory : "",
            terminal: app ? app.runInTerminal : false});
    }
    function receive(line: string): void {
        let data;
        try { data = JSON.parse(line); }
        catch (error) { lastError = "Nieprawidłowa odpowiedź launchera."; return; }
        if (data.type === "ready") {
            deadline.stop();
            history = data.entries;
            historyError = data.error;
            clipboardError = data.clipboardError;
            ready = true;
            send({op: "visible", value: visible});
        } else if (data.type === "history") {
            history = data.entries;
            historyError = data.error;
        } else if (data.type === "clipboard") {
            clipboard = data.entries;
            clipboardError = data.error;
        } else if (data.type === "files") searched(data.revision, data.entries, data.error);
        else if (data.type === "activated") activated(data.request, data.error);
        else if (data.type === "preview") previewed(data.revision, data.key, data.text, data.image, data.error);
    }
    readonly property Process process: Process {
        command: [root.executable, root.helperPath]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root.receive(line) }
        onRunningChanged: {
            if (!running) {
                root.ready = false;
                root.lastError = "Usługa launchera jest niedostępna.";
            }
        }
    }
    readonly property Timer deadline: Timer {
        interval: 5000
        running: true
        onTriggered: {
            root.lastError = "Usługa launchera nie odpowiedziała.";
            root.process.running = false;
        }
    }
    // EOF lets the helper reap watchers and remove its private clipboard DB.
    Component.onDestruction: process.stdinEnabled = false
}
