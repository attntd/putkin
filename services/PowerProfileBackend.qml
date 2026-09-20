import QtQuick
import Quickshell.Io

// The predecessor uses PowerProfiles.profile. In Quickshell 0.3.1 that
// setter is optimistic and exposes neither readiness nor failed writes.
// Use the same PPD interface with confirmed reads and an owner subscription.
QtObject {
    id: root
    readonly property string destination: "org.freedesktop.UPower.PowerProfiles"
    readonly property string objectPath: "/org/freedesktop/UPower/PowerProfiles"
    readonly property var environment: ({LC_ALL: "C", LANG: "C"})
    property string owner: ""
    property var snapshot: null
    readonly property bool available: owner !== "" && snapshot !== null
    readonly property string profile: available ? snapshot.profile : ""
    readonly property var profiles: available ? snapshot.profiles : []
    readonly property string degradationReason: available ? snapshot.degradation : ""
    property string pendingProfile: ""
    readonly property bool busy: pendingProfile !== ""
    property string lastError: ""
    property int generation: 0
    property int queryGeneration: -1
    property int writeGeneration: -1
    property bool readPending: false
    readonly property var watcherProcessId: watcher.processId

    function changeOwner(value: string): void {
        if (value === owner) return;
        generation++;
        owner = value;
        snapshot = null;
        if (busy) lastError = qsTr("Usługa trybów pracy została rozłączona");
        pendingProfile = "";
        if (owner) refresh();
    }
    function receive(line: string): void {
        const prefix = "The name " + destination + " is owned by ";
        if (line.startsWith(prefix)) changeOwner(line.slice(prefix.length).trim());
        else if (line === "The name " + destination + " does not have an owner") changeOwner("");
        else if (line.startsWith(objectPath + ": org.freedesktop.DBus.Properties.PropertiesChanged")) refresh();
    }
    function refresh(): void {
        readPending = true;
        Qt.callLater(read);
    }
    function read(): void {
        if (!owner || query.running || writer.running || !readPending) return;
        readPending = false;
        queryGeneration = generation;
        // Address the captured unique owner: a replacement cannot receive an old request.
        query.command = ["busctl", "--system", "--json=short", "--timeout=2", "--auto-start=no", "call",
            owner, objectPath, "org.freedesktop.DBus.Properties", "GetAll", "s", destination];
        query.running = true;
    }
    function finishRead(code: int): void {
        if (queryGeneration === generation && owner) {
            try {
                if (code !== 0) throw new Error("GetAll failed");
                const reply = JSON.parse(output.text);
                if (reply.type !== "a{sv}" || !reply.data || !reply.data[0]) throw new Error("Invalid reply");
                const values = reply.data[0];
                if (values.ActiveProfile.type !== "s" || values.Profiles.type !== "aa{sv}") throw new Error("Invalid profiles");
                const supported = values.Profiles.data.map(entry => entry.Profile && entry.Profile.type === "s" ? entry.Profile.data : "")
                    .filter(value => ["power-saver", "balanced", "performance"].indexOf(value) >= 0);
                if (supported.indexOf(values.ActiveProfile.data) < 0) throw new Error("Invalid active profile");
                snapshot = {profile: values.ActiveProfile.data, profiles: supported,
                    degradation: values.PerformanceDegraded && values.PerformanceDegraded.type === "s" ? values.PerformanceDegraded.data : ""};
                if (busy && !writer.running && writeGeneration === generation) {
                    lastError = profile === pendingProfile ? "" : qsTr("System nie potwierdził zmiany trybu pracy");
                    pendingProfile = "";
                }
            } catch (error) {
                snapshot = null;
                pendingProfile = "";
                lastError = qsTr("Nie można odczytać trybów pracy");
            }
        }
        Qt.callLater(read);
    }
    function setProfile(value: string): void {
        if (!available || busy || writer.running || profiles.indexOf(value) < 0 || value === profile) return;
        lastError = "";
        pendingProfile = value;
        // Invalidate any read begun before the write, even if it finishes later.
        generation++;
        writeGeneration = generation;
        writer.command = ["busctl", "--system", "--timeout=3", "--auto-start=no", "set-property",
            owner, objectPath, destination, "ActiveProfile", "s", value];
        writer.running = true;
    }
    function finishWrite(code: int): void {
        if (writeGeneration === generation && owner) {
            if (code !== 0) {
                pendingProfile = "";
                lastError = qsTr("Nie udało się zmienić trybu pracy. Sprawdź uprawnienia usługi zasilania.");
            }
            refresh();
        } else if (owner) refresh();
    }
    readonly property Process watcher: Process {
        command: ["gdbus", "monitor", "--system", "--dest", root.destination]
        environment: root.environment
        running: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: StdioCollector {}
        onRunningChanged: {
            if (!running) {
                root.changeOwner("");
                root.lastError = qsTr("Obserwacja trybów pracy niedostępna");
            }
        }
    }
    readonly property Process query: Process {
        environment: root.environment
        stdout: StdioCollector { id: output }
        stderr: StdioCollector {}
    }
    readonly property Process writer: Process {
        environment: root.environment
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
    Component.onCompleted: {
        query.exited.connect((code, _status) => root.finishRead(code));
        writer.exited.connect((code, _status) => root.finishWrite(code));
    }
}
