import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Scope {
    id: root
    // Bluetooth 0.3.1 qmltypes leave UntypedObjectModel unqualified.
    // Keep a dynamic singleton boundary; native imports remain linted/tested.
    readonly property var nativeApi: Bluetooth
    readonly property var nativeAdapters: nativeApi.adapters.values
    readonly property var adapters: available ? nativeAdapters : []
    readonly property bool available: owner.length > 0 && !lifetime.invalid && !watcherFailed
    readonly property bool busy: action.running
    readonly property bool managerBusy: managerProbe.running
    readonly property string lastError: watcherFailed ? qsTr("Obserwacja Bluetooth niedostępna; uruchom ponownie Putkin")
        : !owner && lifetime.missing ? qsTr("BlueZ niedostępny")
        : lifetime.invalid ? qsTr("Uruchom ponownie Putkin, aby odświeżyć połączenie z BlueZ") : ""
    property string managerError: ""
    property string owner: ""
    property bool watcherFailed: false
    property bool stateReady: false
    property bool nativeWarm: false
    property int actionId: -1
    property string actionOwner: ""
    readonly property var watcherProcessId: watcher.processId
    readonly property var commandEnvironment: ({LC_ALL: "C", LANG: "C"})
    signal completed(int serial, string error)
    signal managerRequested

    // Bluez/DBusObjectManager in 0.3.1 cannot rebuild after a service restart.
    // A soft reload keeps the owner history; a warm hard reload is untrusted.
    PersistentProperties {
        id: lifetime
        reloadableId: "putkin-bluetooth-owner"
        property string firstOwner: ""
        property bool invalid: false
        property bool missing: false
        onLoaded: {
            if (!firstOwner && root.nativeWarm) invalid = true;
            root.stateReady = true;
        }
    }
    function receive(line: string): void {
        const prefix = "The name org.bluez is owned by ";
        if (line.startsWith(prefix)) {
            const next = line.slice(prefix.length).trim();
            if (next === owner) return;
            if (lifetime.missing || (lifetime.firstOwner && lifetime.firstOwner !== next))
                lifetime.invalid = true;
            if (!lifetime.firstOwner) lifetime.firstOwner = next;
            owner = next;
        } else if (line === "The name org.bluez does not have an owner") {
            lifetime.missing = true;
            if (lifetime.firstOwner) lifetime.invalid = true;
            owner = "";
        }
    }
    function request(kind: string, target: var, value: bool, serial: int): bool {
        if (!available || busy || !target) return false;
        const radio = kind === "radio";
        if (radio ? adapters.indexOf(target) < 0
                  : kind !== "device" || nativeApi.devices.values.indexOf(target) < 0 || !target.paired)
            return false;
        // Native setters have no operation result in QML (radio is optimistic).
        // Use only these typed calls; state still comes from the native models.
        const prefix = ["busctl", "--system", "--timeout=25", "--auto-start=no"];
        action.command = radio
            ? prefix.concat(["set-property", owner, target.dbusPath, "org.bluez.Adapter1", "Powered", "b", value ? "true" : "false"])
            : prefix.concat(["call", owner, target.dbusPath, "org.bluez.Device1", value ? "Connect" : "Disconnect"]);
        actionId = serial;
        actionOwner = owner;
        action.running = true;
        return true;
    }
    function cancel(serial: int): void {
        if (actionId !== serial) return;
        actionId = -1;
        if (action.running) action.signal(9);
    }
    function openManager(): void {
        if (managerBusy) return;
        managerError = "";
        managerProbe.running = true;
    }
    readonly property Process watcher: Process {
        command: ["gdbus", "monitor", "--system", "--dest", "org.bluez", "--object-path", "/"]
        environment: root.commandEnvironment
        running: root.stateReady
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: StdioCollector {}
        onRunningChanged: { if (!running) root.watcherFailed = true; }
    }
    readonly property Process action: Process {
        environment: root.commandEnvironment
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
    readonly property Timer actionDeadline: Timer {
        interval: 26000
        running: root.action.running
        onTriggered: {
            const serial = root.actionId;
            root.cancel(serial);
            root.completed(serial, qsTr("Przekroczono czas operacji Bluetooth"));
        }
    }
    readonly property Process managerProbe: Process {
        // Constant command: device names and addresses never enter a shell.
        command: ["sh", "-c", "command -v blueman-manager"]
        environment: root.commandEnvironment
        stdout: StdioCollector { id: managerPath }
        stderr: StdioCollector {}
    }
    readonly property Timer managerDeadline: Timer {
        interval: 1500
        running: root.managerProbe.running
        onTriggered: {
            root.managerProbe.signal(9);
            root.managerError = qsTr("Nie można znaleźć menedżera Bluetooth");
        }
    }
    Component.onCompleted: {
        nativeWarm = nativeAdapters.length > 0;
        action.exited.connect((code, _status) => {
            const serial = root.actionId;
            root.actionId = -1;
            if (serial < 0) return;
            root.completed(serial, root.actionOwner !== root.owner || !root.available
                ? qsTr("BlueZ jest już niedostępny")
                : code === 0 ? "" : qsTr("BlueZ odrzucił operację. Sprawdź urządzenie, blokadę i uprawnienia."));
        });
        managerProbe.exited.connect((code, _status) => {
            const path = managerPath.text.trim();
            if (code !== 0 || !path.startsWith("/"))
                root.managerError = qsTr("Brak blueman-manager. Zainstaluj Blueman, aby parować nowe urządzenia.");
            else {
                Quickshell.execDetached([path]);
                root.managerRequested();
            }
        });
    }
}
