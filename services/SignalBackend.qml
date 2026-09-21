import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string helperPath: decodeURIComponent(Qt.resolvedUrl("signal_backend.py").toString().replace(/^file:\/\//, ""))
    // Explicit injection for the isolated harness; production supplies neither.
    property var helperArguments: []
    property var helperEnvironment: ({})
    property string generation: ""
    property string serviceState: "starting"
    property string accountState: "unlinked"
    property string accountId: ""
    property int schemaVersion: 0
    property string errorCode: ""
    property string eventErrorLocation: ""
    property string cliVersion: ""
    property var capabilities: []
    property var configuration: ({enabled: false, deviceName: "Putkin"})
    property string linkAttempt: ""
    property string linkError: ""
    property bool reconciling: false
    property var pending: ({})
    property int counter: 0
    property bool stopping: false
    property string lastSequence: "0"
    readonly property int processId: worker.processId || 0
    readonly property bool ready: serviceState === "ready"
    signal response(string requestId, var result, var error)
    signal event(string name, var data)

    function invalidate(code: string): void {
        const ids = Object.keys(pending);
        pending = ({});
        for (const requestId of ids) response(requestId, null, {code: code, retryable: false});
    }
    function fail(code: string): void {
        startup.stop();
        serviceState = "failed";
        errorCode = code;
        linkAttempt = "";
        reconciling = false;
        if (accountState === "linking") accountState = "unlinked";
        generation = "";
        invalidate("result_unknown");
    }
    function applyState(data: var): bool {
        if (!data || data.ipcVersion !== 1 || [0, 1, 2, 3, 4, 5, 6, 7].indexOf(data.schemaVersion) < 0
                || ["disabled", "idle", "starting", "ready", "reconnecting", "stopping", "failed"].indexOf(data.serviceState) < 0
                || ["unlinked", "linking", "linked", "relinkRequired"].indexOf(data.accountState) < 0
                || !Array.isArray(data.capabilities) || typeof data.errorCode !== "string"
                || typeof data.cliVersion !== "string") return false;
        serviceState = data.serviceState;
        accountState = data.accountState;
        accountId = data.accountId || "";
        schemaVersion = data.schemaVersion;
        errorCode = data.errorCode;
        eventErrorLocation = data.eventErrorLocation || "";
        cliVersion = data.cliVersion;
        capabilities = data.capabilities;
        configuration = data.configuration || ({enabled: false, deviceName: "Putkin"});
        linkAttempt = data.linkAttempt || "";
        linkError = data.linkError || "";
        reconciling = data.reconciling || false;
        return true;
    }
    function receive(line: string): void {
        let value;
        try { value = JSON.parse(line); }
        catch (_) { fail("invalid_frame"); worker.stdinEnabled = false; return; }
        if (!value || value.v !== 1 || typeof value.generation !== "string" || !value.generation) {
            fail("unsupported_version"); worker.stdinEnabled = false; return;
        }
        if (value.type === "hello") {
            invalidate("result_unknown");
            if (!applyState(value.data)) { fail("invalid_frame"); worker.stdinEnabled = false; return; }
            generation = value.generation;
            lastSequence = "0";
            startup.stop();
        } else if (value.generation !== generation) {
            return;
        } else if (value.type === "response") {
            if (!Object.prototype.hasOwnProperty.call(pending, value.id)) return;
            if ((value.result !== undefined) === (value.error !== undefined)) {
                fail("invalid_frame"); worker.stdinEnabled = false; return;
            }
            delete pending[value.id];
            response(value.id, value.result === undefined ? null : value.result, value.error || null);
        } else if (value.type === "event") {
            const seq = Number(value.seq);
            if (typeof value.seq !== "string" || !Number.isSafeInteger(seq) || seq !== Number(lastSequence) + 1) {
                fail("event_gap"); worker.stdinEnabled = false; return;
            }
            lastSequence = value.seq;
            if (value.name === "service.changed" && !applyState(value.data)) {
                fail("invalid_frame"); worker.stdinEnabled = false; return;
            }
            event(value.name, value.data);
        } else {
            fail("invalid_frame"); worker.stdinEnabled = false;
        }
    }
    function request(method: string, params: var): string {
        if (!generation || stopping || !worker.running || Object.keys(pending).length >= 32
                || capabilities.indexOf(method) < 0) return "";
        const requestId = "qml-" + (++counter);
        const raw = JSON.stringify({v: 1, type: "request", generation: generation,
            id: requestId, method: method, params: params || {}});
        // Conservative UTF-8 upper bound; payloads are bounded again in Python.
        if (raw.length * 3 + 1 > 1024 * 1024) return "";
        pending[requestId] = true;
        worker.write(raw + "\n");
        return requestId;
    }
    function retry(): bool {
        if (worker.running) return request("service.retry", {}) !== "";
        if (stopping) return false;
        serviceState = "starting";
        errorCode = "";
        worker.stdinEnabled = true;
        worker.running = true;
        startup.restart();
        return true;
    }
    readonly property Process worker: Process {
        command: ["python3", "-B", root.helperPath, "--owner-pid", String(Quickshell.processId)].concat(root.helperArguments)
        environment: root.helperEnvironment
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        // CLI stderr is /dev/null in Python; never echo private payloads here.
        stderr: SplitParser { onRead: _data => {} }
    }
    readonly property Timer startup: Timer {
        interval: 15000
        running: true
        onTriggered: { root.fail("timeout"); root.worker.stdinEnabled = false; }
    }
    Component.onCompleted: {
        worker.exited.connect(() => { if (!root.stopping) root.fail("transport_lost"); });
    }
    Component.onDestruction: {
        stopping = true;
        worker.stdinEnabled = false;
    }
}
