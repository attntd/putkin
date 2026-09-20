import QtQuick
import "Backlight.js" as Backlight

QtObject {
    id: root
    required property var backend
    property var sample: null
    property bool initialized: false
    readonly property bool available: sample !== null
    readonly property string device: available ? sample.device : ""
    readonly property real percent: available ? sample.current * 100 / sample.maximum : -1
    readonly property real requestedPercent: pending ? pending.percent : Math.max(1, percent)
    readonly property string statusText: !initialized ? qsTr("Odczytywanie podświetlenia…")
        : !available ? qsTr("Podświetlenie niedostępne") : Math.round(percent) + "%"
    property string lastError: ""
    property string diagnostic: qsTr("Odczytywanie podświetlenia…")
    property var pending: null
    property var active: null
    property bool refreshQueued: false
    property string refreshError: ""
    property int revision: 0
    property int sequence: 0
    property int writeInterval: 120
    readonly property bool busy: active !== null || pending !== null || refreshQueued
    signal feedback(string monitor)

    function reject(message: string): bool { lastError = message; return false; }
    function describe(): string {
        return available ? qsTr("Urządzenie: %1 · zakres 0–%2. Stan odświeża się po otwarciu panelu i własnej zmianie.").arg(device).arg(sample.maximum)
            : qsTr("Nie wykryto dostępnego podświetlenia laptopa. Monitory DDC nie są obsługiwane.");
    }
    function setPercent(value: var, monitor: string): bool {
        if (typeof value !== "number" || !isFinite(value) || value < 1 || value > 100)
            return reject(qsTr("Jasność musi być liczbą od 1 do 100."));
        if (!available) return reject(qsTr("Podświetlenie jest niedostępne. Odśwież jego stan."));
        pending = { revision: ++revision, device: device, maximum: sample.maximum,
            raw: Backlight.raw(value, sample.maximum), percent: value, monitor: monitor };
        lastError = "";
        Qt.callLater(pump);
        return true;
    }
    function change(points: var, monitor: string): bool {
        if (typeof points !== "number" || !isFinite(points) || Math.abs(points) > 100)
            return reject(qsTr("Zmiana jasności musi być liczbą od −100 do 100."));
        let target = Math.max(1, Math.min(100, requestedPercent + points));
        if (available && points !== 0) {
            const baseRaw = pending ? pending.raw : sample.current;
            if (Backlight.raw(target, sample.maximum) === baseRaw) {
                // Coarse firmware ranges must still move with a small shortcut.
                const nextRaw = Math.min(sample.maximum, Math.max(Math.ceil(sample.maximum / 100), baseRaw + (points > 0 ? 1 : -1)));
                target = Math.max(1, nextRaw * 100 / sample.maximum);
            }
        }
        return setPercent(target, monitor);
    }
    function setIdlePercent(value: real): bool {
        if (!setPercent(value, "")) return false;
        pending.silent = true;
        return true;
    }
    function refresh(): void {
        refreshQueued = true;
        refreshError = "";
        Qt.callLater(pump);
    }
    function start(request: var, arguments: var): void {
        request.id = ++sequence;
        active = request;
        if (!backend.run(request.id, arguments)) {
            active = null;
            pending = null;
            refreshQueued = false;
            lastError = qsTr("Adapter podświetlenia jest zajęty. Spróbuj ponownie.");
        }
    }
    function pump(): void {
        if (active) return;
        if (pending) {
            if (throttle.running) return;
            throttle.restart();
            start(Object.assign({ kind: "set" }, pending),
                ["--class=backlight", "--device=" + pending.device, "--quiet", "set", String(pending.raw)]);
        } else if (refreshQueued) {
            refreshQueued = false;
            start({ kind: "list", revision: revision, keepError: refreshError },
                ["--class=backlight", "--machine-readable", "--list"]);
        }
    }
    function failure(result: var): string {
        if (result.failure === "timeout") return qsTr("Przekroczono czas operacji podświetlenia. Spróbuj ponownie.");
        if (result.failure === "start") return qsTr("Nie można uruchomić brightnessctl. Sprawdź, czy jest zainstalowany.");
        if (result.failure || result.code !== 0 || result.error.trim())
            return qsTr("Nie udało się odczytać lub zmienić podświetlenia (kod %1). Sprawdź uprawnienia.").arg(result.code)
                + (result.error.trim() ? "\n" + result.error.trim().slice(0, 500) : "");
        return "";
    }
    function receive(requestId: int, result: var): void {
        if (!active || active.id !== requestId) return;
        const request = active;
        active = null;
        // Older replies may finish, but cannot publish state or feedback over
        // a newer intent. The next write always waits for the child to exit.
        if (request.revision !== revision) { Qt.callLater(pump); return; }
        let error = failure(result);
        const absent = request.kind === "list" && !result.failure && result.code === 1
            && result.error.trim() === "Failed to read any devices of class 'backlight'.";
        if (absent) error = "";
        if (request.kind === "set" && !error) {
            start(Object.assign({}, request, { kind: "verify" }),
                ["--class=backlight", "--device=" + request.device, "--machine-readable", "info"]);
            return;
        }
        let devices = [];
        if (request.kind !== "set" && !error && !absent) {
            const parsed = Backlight.parse(result.output);
            devices = parsed.devices;
            if (parsed.error) error = parsed.error === "range"
                ? qsTr("Podświetlenie zgłasza nieprawidłowy lub zerowy zakres.")
                : qsTr("Niepoprawna odpowiedź brightnessctl; zakres podświetlenia jest nieznany.");
        }
        if (request.kind === "list") {
            sample = error ? null : devices.find(candidate => candidate.device === device) || devices[0] || null;
            initialized = true;
            lastError = error || request.keepError;
            diagnostic = error || describe();
        } else if (request.kind === "verify") {
            const value = devices.length === 1 && devices[0].device === request.device ? devices[0] : null;
            if (!error && (!value || value.maximum !== request.maximum || value.current !== request.raw))
                error = qsTr("Odczyt nie potwierdził żądanej jasności. Odśwież stan i spróbuj ponownie.");
            if (value) sample = value;
            else if (error) sample = null;
            pending = null;
            refreshQueued = false; // This read also satisfies a queued refresh.
            lastError = error;
            diagnostic = error || describe();
            if (!error && !request.silent) feedback(request.monitor);
        } else {
            pending = null;
            lastError = error;
            // A failed write is not success; read back without erasing its error.
            refreshQueued = true;
            refreshError = error;
        }
        Qt.callLater(pump);
    }
    readonly property Timer throttle: Timer { interval: root.writeInterval; onTriggered: root.pump() }
    readonly property Connections changes: Connections {
        target: root.backend
        function onCompleted(requestId: int, result: var): void { root.receive(requestId, result); }
    }
    Component.onCompleted: refresh()
}
