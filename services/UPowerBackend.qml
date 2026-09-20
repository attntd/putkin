import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

QtObject {
    id: root
    readonly property var nativeDevice: UPower.displayDevice
    readonly property var commandEnvironment: ({ LC_ALL: "C", LANG: "C" })
    property string owner: ""
    property bool recovery: false
    property var recoveredDevice: null
    property string lastError: ""
    property int generation: 0
    property int readGeneration: -1
    property bool readPending: false
    readonly property bool available: owner.length > 0 && (recovery ? recoveredDevice !== null : nativeDevice.ready)
    readonly property var device: !available ? null : recovery ? recoveredDevice : nativeDevice
    readonly property var watcherProcessId: watcher.processId

    // 0.3.1 has no service-owner watcher/reinitialization. This read-only
    // signal subscription closes that gap; no polling, daemon or hardware writes.
    // C locale and exact prefixes: never parse values out of GVariant text.
    function receive(line: string): void {
        const prefix = "The name org.freedesktop.UPower is owned by ";
        if (line.startsWith(prefix)) {
            const next = line.slice(prefix.length).trim();
            if (next === owner) return;
            if (owner.length > 0) recovery = true;
            owner = next;
            generation++;
            if (recovery) scheduleRead();
            else nativeDeadline.restart();
        } else if (line === "The name org.freedesktop.UPower does not have an owner") {
            owner = "";
            generation++;
            recovery = true;
            recoveredDevice = null;
            nativeDeadline.stop();
        } else if (recovery && line.startsWith("/org/freedesktop/UPower/devices/DisplayDevice: org.freedesktop.DBus.Properties.PropertiesChanged")) {
            scheduleRead();
        }
    }
    function scheduleRead(): void {
        readPending = true;
        Qt.callLater(read);
    }
    function read(): void {
        if (!owner || query.running || !readPending) return;
        readPending = false;
        readGeneration = generation;
        query.running = true;
    }
    function finish(code: int): void {
        if (readGeneration === generation && owner) {
            try {
                if (code !== 0) throw new Error("UPower GetAll failed");
                const reply = JSON.parse(output.text);
                if (reply.type !== "a{sv}" || !reply.data || !reply.data[0]) throw new Error("Invalid UPower reply");
                const values = reply.data[0];
                const get = (name, type) => {
                    if (!values[name] || values[name].type !== type) throw new Error("Missing UPower property: " + name);
                    return values[name].data;
                };
                const type = get("Type", "u");
                recoveredDevice = { ready: true, isPresent: get("IsPresent", "b"),
                    isLaptopBattery: type === 2 && get("PowerSupply", "b"),
                    percentage: get("Percentage", "d") / 100, state: get("State", "u"),
                    timeToEmpty: get("TimeToEmpty", "x"), timeToFull: get("TimeToFull", "x") };
                lastError = "";
            } catch (error) {
                recoveredDevice = null;
                lastError = qsTr("Nie można odczytać baterii");
            }
        }
        Qt.callLater(read);
    }
    readonly property Timer nativeDeadline: Timer {
        interval: 500
        onTriggered: {
            if (root.owner && !root.nativeDevice.ready) {
                root.recovery = true;
                root.scheduleRead();
            }
        }
    }
    readonly property Process watcher: Process {
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.UPower"]
        environment: root.commandEnvironment
        running: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: StdioCollector { }
        onRunningChanged: {
            if (!running) {
                root.owner = "";
                root.generation++;
                root.recoveredDevice = null;
                root.lastError = qsTr("Obserwacja baterii niedostępna");
            }
        }
    }
    readonly property Process query: Process {
        command: ["busctl", "--system", "--json=short", "--timeout=2", "--auto-start=no", "call",
            "org.freedesktop.UPower", "/org/freedesktop/UPower/devices/DisplayDevice",
            "org.freedesktop.DBus.Properties", "GetAll", "s", "org.freedesktop.UPower.Device"]
        environment: root.commandEnvironment
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { }
    }
    Component.onCompleted: {
        // A pre-existing ready C++ singleton can be stale after a QML reload.
        if (nativeDevice.ready) recovery = true;
        query.exited.connect((code, _status) => root.finish(code));
    }
}
