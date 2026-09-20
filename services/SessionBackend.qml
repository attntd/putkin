import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string helperPath: Quickshell.shellPath("services/session_backend.py")
    property var helperEnvironment: ({})
    property var capabilities: ({})
    property string sessionId: ""
    property bool confirmationAvailable: false
    property bool ready: false
    property string errorText: ""
    property bool stopping: false
    property bool started: false
    required property var lockService
    property int lockToken: 0
    property bool idleReady: false
    property bool idleInhibited: true
    property bool sleepInhibited: true
    property bool fingerprintAvailable: false
    property bool unlockHeld: false
    readonly property int processId: worker.processId || 0
    signal completed(int requestId, bool success, string message)
    signal progress(int requestId, string phase)
    signal resumed()

    function send(value: var): void { worker.write(JSON.stringify(value) + "\n"); }
    function request(id: int, action: string): bool {
        if (!ready) return false;
        send({ id: id, action: action });
        return true;
    }
    function cancel(id: int): void { if (ready) send({ id: id, action: "cancel" }); }
    function refresh(): void { if (ready) send({ action: "refresh" }); }
    function lockState(): void {
        if (ready) send({ action: "lock-state", token: lockToken, locked: lockService.locked, secure: lockService.secure });
    }
    function setIdleHint(idle: bool): void { if (ready) send({ action: "idle-hint", idle: idle }); }
    function fail(): void {
        ready = false;
        capabilities = {};
        confirmationAvailable = false;
        idleReady = false;
        idleInhibited = sleepInhibited = true;
        unlockHeld = false;
        errorText = qsTr("Adapter sesji niedostępny. Sprawdź Python, python-dbus, python-gobject i D-Bus; uruchom ponownie Putkin.");
        startup.stop();
        if (worker.running && worker.processId > 0) worker.signal(9);
    }
    function receive(line: string): void {
        let value;
        try { value = JSON.parse(line); }
        catch (_) { fail(); return; }
        if (value.state !== undefined) {
            capabilities = value.state;
            sessionId = value.session;
            confirmationAvailable = value.confirmation;
            idleReady = value.idleReady;
            idleInhibited = value.idleInhibited;
            sleepInhibited = value.sleepInhibited;
            fingerprintAvailable = value.fingerprint;
            errorText = value.error;
            const first = !ready;
            ready = true;
            startup.stop();
            if (first) lockState();
        } else if (value.lockRequest !== undefined) {
            lockToken = value.lockRequest;
            lockService.request();
            lockState();
        } else if (value.hold !== undefined) {
            unlockHeld = value.hold;
        } else if (value.completed !== undefined)
            completed(value.completed, value.success, value.message);
        else if (value.progress !== undefined)
            progress(value.progress, value.phase);
        else if (value.resumed === true)
            resumed();
    }
    readonly property Process worker: Process {
        command: ["python3", "-B", root.helperPath]
        environment: root.helperEnvironment
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        // Diagnostics stay in the Quickshell log; no passwords cross this pipe.
        stderr: SplitParser { onRead: data => { console.error("Session backend: " + data); root.fail(); } }
        onStarted: root.started = true
        onRunningChanged: { if (!running && !root.started && !root.stopping) root.fail(); }
    }
    readonly property Timer startup: Timer { interval: 12000; onTriggered: root.fail() }
    readonly property Connections lockEvents: Connections {
        target: root.lockService
        function onLockedChanged(): void { root.lockState(); }
        function onSecureChanged(): void { root.lockState(); }
    }
    Component.onCompleted: {
        worker.exited.connect(() => { if (!root.stopping) root.fail(); });
        startup.start();
        worker.running = true;
    }
    Component.onDestruction: {
        stopping = true;
        if (worker.running && worker.processId > 0) worker.signal(9);
    }
}
