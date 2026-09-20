import QtQuick

QtObject {
    id: root
    required property var backend
    property var sample: null
    property int sequence: 0
    property int activeId: -1
    property int preferredTemperature: 4500
    property bool refreshQueued: false
    property string lastError: ""
    property bool initialized: false
    readonly property bool available: sample !== null
    readonly property bool enabled: available && sample.enabled
    readonly property int temperature: available ? sample.temperature : 0
    readonly property bool busy: activeId >= 0
    readonly property string statusText: !initialized ? qsTr("Odczytywanie…") : !available ? qsTr("Niedostępne")
        : enabled ? qsTr("Włączone · %1 K").arg(temperature) : qsTr("Wyłączone")
    signal refreshed()

    function errorText(code: string): string {
        switch (code) {
        case "absent": case "session": return qsTr("Brak działającego Night Light w tej sesji.");
        case "service": case "owner": return qsTr("Night Light wymaga usługi użytkownika hyprsunset.service w tej sesji.");
        case "version": return qsTr("Night Light wymaga hyprsunset 0.4.0. Sprawdź wersję i uruchom ponownie jego usługę.");
        case "timeout": return qsTr("Przekroczono czas operacji. Odśwież stan przed kolejną zmianą.");
        case "restart": return qsTr("Usługa Night Light została uruchomiona ponownie. Odśwież stan.");
        case "denied": return qsTr("Odmowa zmiany Night Light. Sprawdź uprawnienia usługi.");
        case "unconfirmed": return qsTr("Odczyt nie potwierdził zmiany Night Light. Odśwież stan.");
        case "helper": return qsTr("Nie można uruchomić adaptera Night Light.");
        default: return qsTr("Nieprawidłowa odpowiedź Night Light. Odśwież stan.");
        }
    }
    function start(arguments: var): bool {
        if (busy) return false;
        activeId = ++sequence;
        lastError = "";
        if (backend.run(activeId, arguments)) return true;
        activeId = -1;
        sample = null;
        lastError = errorText("helper");
        return false;
    }
    function refresh(): void {
        if (busy) { refreshQueued = true; return; }
        start(["read"]);
    }
    function setEnabled(value: bool): bool {
        if (!available || busy) return false;
        return start(["set", sample.owner, value ? "on" : "off", String(preferredTemperature)]);
    }
    function setTemperature(value: var): bool {
        if (!available || !enabled || busy || typeof value !== "number" || !Number.isFinite(value) || value < 1000 || value > 6500) return false;
        return start(["set", sample.owner, "on", String(Math.round(value))]);
    }
    function receive(id: int, result: var): void {
        if (id !== activeId) return;
        activeId = -1;
        initialized = true;
        const next = result ? result.sample : null;
        const valid = next && typeof next.enabled === "boolean" && typeof next.owner === "string" && /^[0-9]+:[0-9]+$/.test(next.owner)
            && Number.isInteger(next.temperature) && next.temperature >= 1000 && next.temperature <= 20000;
        sample = valid && !result.error ? next : null;
        lastError = sample ? "" : errorText(result && result.error ? result.error : "protocol");
        if (sample && enabled && temperature <= 6500) preferredTemperature = temperature;
        // A failed write is never automatically retried or hidden by a refresh.
        if (refreshQueued && sample) { refreshQueued = false; Qt.callLater(refresh); }
        else refreshQueued = false;
        refreshed();
    }
    readonly property Connections replies: Connections {
        target: root.backend
        function onCompleted(requestId: int, result: var): void { root.receive(requestId, result); }
    }
    Component.onCompleted: refresh()
}
