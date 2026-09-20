pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root
    property bool available: false
    property string errorText: ""
    property string phase: ""
    property bool stopping: false
    property bool probeStarted: false
    property bool monitorStarted: false
    property string ownerName: ""
    readonly property bool serverLoaded: serverLoader.active
    readonly property int watcherPid: monitor.processId || 0
    readonly property NotificationServer server: serverLoader.active ? serverLoader.item as NotificationServer : null
    readonly property var tracked: server ? server.trackedNotifications.values : []
    signal notification(var value, real id)
    signal replacement(real id, var actions, int timeout)


    function fail(message: string): void {
        available = false;
        errorText = message;
        phase = "failed";
        deadline.stop();
        if (monitor.running) monitor.running = false;
    }
    function query(next: string, method: string): void {
        phase = next;
        probeStarted = false;
        probe.command = ["busctl", "--user", "--timeout=2", "--json=short", "call",
            "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
            method, "s", "org.freedesktop.Notifications"];
        probe.running = true;
    }
    function result(code: int): void {
        if (stopping || phase === "failed") return;
        if (code !== 0) { fail(qsTr("Nie można sprawdzić serwera powiadomień. Uruchom ponownie Putkin.")); return; }
        let value;
        try { value = JSON.parse(output.text).data[0]; }
        catch (_) { fail(qsTr("Nieprawidłowa odpowiedź D-Bus powiadomień.")); return; }
        const step = phase;
        Qt.callLater(() => {
            if (root.stopping || root.phase === "failed") return;
            if (step === "initial") {
                if (value) root.query("owner", "GetConnectionUnixProcessID");
                else root.startMonitor();
            } else if (step === "owner") {
                if (value === Quickshell.processId) root.startMonitor();
                else root.fail(qsTr("Powiadomienia obsługuje inny serwer. Przełącz go przed ponownym uruchomieniem Putkin."));
            } else if (step === "verify") {
                if (value !== Quickshell.processId) root.fail(qsTr("Nazwa powiadomień została zajęta. Uruchom ponownie Putkin po przełączeniu serwera."));
                else root.query("ownerName", "GetNameOwner");
            } else if (step === "ownerName") {
                root.ownerName = value;
                root.phase = "ready"; root.available = true; root.deadline.stop();
            }
        });
    }
    function startMonitor(): void {
        phase = "monitoring";
        monitor.running = true;
    }
    function message(data: string): void {
        // Never log messages or retain their body/image/hints. This stream
        // supplements two verified 0.3.1 replacement bugs, not the server.
        let message;
        try { message = JSON.parse(data); } catch (_) { fail(qsTr("Utracono obserwację aktualizacji powiadomień.")); return; }
        if (message.ready === true && phase === "monitoring") {
            phase = "loading";
            serverLoader.active = true;
            query("verify", "GetConnectionUnixProcessID");
            return;
        }
        if (message.owner !== undefined) {
            if (phase === "ready" && message.owner !== ownerName) fail(qsTr("Utracono serwer powiadomień. Uruchom ponownie Putkin."));
            return;
        }
        if (message.id > 0 && (message.destination === "org.freedesktop.Notifications" || message.destination === ownerName))
            replacement(message.id, message.actions, message.timeout);
    }
    readonly property Process probe: Process {
        stdout: StdioCollector { id: output }
        stderr: StdioCollector {}
        onStarted: root.probeStarted = true
        onRunningChanged: {
            if (!running && !root.probeStarted && !root.stopping)
                root.fail(qsTr("Brak narzędzia busctl dla powiadomień."));
        }
    }
    readonly property Process monitor: Process {
        command: ["python3", "-B", Quickshell.shellPath("services/notification-watch.py")]
        onStarted: root.monitorStarted = true
        onRunningChanged: {
            if (!running && !root.monitorStarted && !root.stopping && root.phase !== "failed")
                root.fail(qsTr("Brak Pythona dla obserwatora powiadomień."));
        }
        stdout: SplitParser { onRead: data => root.message(data) }
        stderr: SplitParser { onRead: _data => { if (!root.stopping && root.phase !== "failed") root.fail(qsTr("Obserwator powiadomień niedostępny. Sprawdź python-dbus, python-gobject i dostęp do D-Bus; uruchom ponownie Putkin.")); } }
    }
    readonly property LazyLoader serverLoader: LazyLoader {
        NotificationServer {
            keepOnReload: false
            bodySupported: true
            actionsSupported: true
            imageSupported: true
            persistenceSupported: false
            bodyMarkupSupported: false
            bodyHyperlinksSupported: false
            bodyImagesSupported: false
            actionIconsSupported: false
            inlineReplySupported: false
            onNotification: value => root.notification(value, value.id)
        }
    }
    readonly property Timer deadline: Timer {
        interval: 5000
        onTriggered: {
            root.fail(qsTr("Przekroczono czas uruchamiania powiadomień."));
            if (root.probe.running && root.probe.processId > 0) root.probe.signal(9);
        }
    }
    Component.onCompleted: {
        probe.exited.connect((code, _status) => root.result(code));
        monitor.exited.connect((_code, _status) => {
            if (!root.stopping && root.phase !== "failed") root.fail(qsTr("Obserwator powiadomień zakończył pracę. Uruchom ponownie Putkin."));
        });
        deadline.start();
        query("initial", "NameHasOwner");
    }
    Component.onDestruction: {
        stopping = true;
        if (monitor.running && monitor.processId > 0) monitor.signal(9);
        if (probe.running && probe.processId > 0) probe.signal(9);
    }
}
