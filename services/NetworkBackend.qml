import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Scope {
    id: root
    readonly property bool nativeAvailable: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var devices: available ? Networking.devices.values : []
    readonly property bool available: nativeAvailable && owner.length > 0 && confirmed && !lifetime.invalid
    readonly property bool wifiEnabled: available && radioValue
    readonly property bool hardwareEnabled: available && hardwareValue
    readonly property int connectivity: available ? Networking.connectivity : NetworkConnectivity.Unknown
    readonly property bool connectivityCheckEnabled: available && Networking.connectivityCheckEnabled && Networking.canCheckConnectivity
    property string lastError: ""
    property string editorError: ""
    property string owner: ""
    property bool confirmed: false
    property bool radioValue: false
    property bool hardwareValue: false
    property bool readPending: false
    property int revision: 0
    property int readRevision: -1
    property bool stateReady: false
    property bool nativeWarm: false
    readonly property var watcherProcessId: watcher.processId
    readonly property var commandEnvironment: ({
            LC_ALL: "C",
            LANG: "C"
        })
    signal radioConfirmed
    signal radioFailed(string message)
    // The C++ singleton cannot reinitialize after NM restart in 0.3.1.
    // Persist only its owner identity, never connection data or secrets.
    PersistentProperties {
        id: lifetime
        reloadableId: "putkin-network-owner"
        property string firstOwner: ""
        property bool invalid: false
        onLoaded: {
            // A hard reload discards QML state but retains the C++ singleton.
            // Without its owner history, require a fresh process.
            if (!firstOwner && root.nativeWarm) invalid = true;
            root.stateReady = true;
        }
    }
    function receive(line: string): void {
        const prefix = "The name org.freedesktop.NetworkManager is owned by ";
        if (line.startsWith(prefix)) {
            const next = line.slice(prefix.length).trim();
            if (next === owner)
                return;
            owner = next;
            revision++;
            if (lifetime.firstOwner && lifetime.firstOwner !== next)
                lifetime.invalid = true;
            if (!lifetime.firstOwner)
                lifetime.firstOwner = next;
            if (lifetime.invalid || !nativeAvailable) {
                lastError = qsTr("Uruchom ponownie Putkin, aby odświeżyć połączenie z NetworkManagerem");
            } else
                scheduleRead();
        } else if (line === "The name org.freedesktop.NetworkManager does not have an owner") {
            if (lifetime.firstOwner)
                lifetime.invalid = true;
            owner = "";
            confirmed = false;
            revision++;
            lastError = qsTr("NetworkManager niedostępny");
        } else if (line.startsWith("/org/freedesktop/NetworkManager: org.freedesktop.DBus.Properties.PropertiesChanged"))
            scheduleRead();
    }
    function scheduleRead(): void {
        readPending = true;
        readSoon.restart();
    }
    function read(): void {
        if (!owner || query.running || !readPending || lifetime.invalid)
            return;
        readPending = false;
        readRevision = revision;
        query.running = true;
    }
    function finishRead(code: int): void {
        if (readRevision === revision && owner) {
            try {
                if (code !== 0)
                    throw new Error("GetAll");
                const reply = JSON.parse(output.text);
                const values = reply.type === "a{sv}" && reply.data ? reply.data[0] : null;
                if (!values || values.WirelessEnabled.type !== "b" || values.WirelessHardwareEnabled.type !== "b")
                    throw new Error("properties");
                radioValue = values.WirelessEnabled.data;
                hardwareValue = values.WirelessHardwareEnabled.data;
                confirmed = true;
                lastError = "";
                radioConfirmed();
            } catch (error) {
                confirmed = false;
                lastError = qsTr("Nie można potwierdzić stanu NetworkManagera");
            }
        }
        if (readPending)
            readSoon.restart();
    }
    function setWifiEnabled(value: bool): void {
        if (!available || radioWrite.running) {
            radioFailed(qsTr("Zmiana radia niedostępna"));
            return;
        }
        // Native 0.3.1's optimistic setter also suppresses retries after a
        // denied write. Use only this boolean D-Bus property via busctl.
        radioWrite.command = ["busctl", "--system", "--timeout=2", "--auto-start=no", "set-property", "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "WirelessEnabled", "b", value ? "true" : "false"];
        radioWrite.running = true;
    }
    function checkConnectivity(): void {
        if (connectivityCheckEnabled)
            Networking.checkConnectivity();
    }
    function openEditor(): void {
        if (editorProbe.running)
            return;
        editorError = "";
        editorProbe.running = true;
    }
    readonly property Timer readSoon: Timer {
        interval: 0
        onTriggered: root.read()
    }
    readonly property Process watcher: Process {
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.NetworkManager", "--object-path", "/org/freedesktop/NetworkManager"]
        environment: root.commandEnvironment
        running: root.stateReady
        stdout: SplitParser {
            onRead: data => root.receive(data)
        }
        stderr: StdioCollector {}
        onRunningChanged: {
            if (!running) {
                root.owner = "";
                root.confirmed = false;
                root.revision++;
                root.lastError = qsTr("Obserwacja sieci niedostępna; uruchom ponownie Putkin");
            }
        }
    }
    readonly property Process query: Process {
        command: ["busctl", "--system", "--json=short", "--timeout=2", "--auto-start=no", "call", "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.DBus.Properties", "GetAll", "s", "org.freedesktop.NetworkManager"]
        environment: root.commandEnvironment
        stdout: StdioCollector {
            id: output
        }
        stderr: StdioCollector {}
    }
    readonly property Timer queryDeadline: Timer {
        interval: 2500
        running: root.query.running
        onTriggered: {
            root.query.signal(9);
            root.confirmed = false;
            root.lastError = qsTr("Odczyt sieci przekroczył limit czasu");
        }
    }
    readonly property Process radioWrite: Process {
        environment: root.commandEnvironment
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
    readonly property Timer writeDeadline: Timer {
        interval: 2500
        running: root.radioWrite.running
        onTriggered: {
            root.radioWrite.signal(9);
            root.radioFailed(qsTr("Zmiana radia przekroczyła limit czasu"));
        }
    }
    readonly property Process editorProbe: Process {
        // Constant command; SSIDs and passwords never reach a shell or argv.
        command: ["sh", "-c", "command -v nm-connection-editor"]
        environment: root.commandEnvironment
        stdout: StdioCollector {
            id: editorPath
        }
        stderr: StdioCollector {}
    }
    readonly property Timer editorDeadline: Timer {
        interval: 1500
        running: root.editorProbe.running
        onTriggered: {
            root.editorProbe.signal(9);
            root.editorError = qsTr("Nie można znaleźć edytora połączeń");
        }
    }
    Component.onCompleted: {
        nativeWarm = Networking.devices.values.length > 0 || Networking.wifiEnabled
            || Networking.canCheckConnectivity || Networking.connectivity !== NetworkConnectivity.Unknown;
        query.exited.connect((code, _status) => root.finishRead(code));
        radioWrite.exited.connect((code, _status) => {
            if (code !== 0)
                root.radioFailed(qsTr("Nie można zmienić radia. Sprawdź uprawnienia i rfkill."));
            root.scheduleRead();
        });
        editorProbe.exited.connect((code, _status) => {
            const path = editorPath.text.trim();
            if (code !== 0 || !path.startsWith("/"))
                root.editorError = qsTr("Brak nm-connection-editor. Zainstaluj go, aby edytować VPN i profile zaawansowane.");
            else
                Quickshell.execDetached([path]);
        });
    }
}
