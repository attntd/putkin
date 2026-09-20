import QtQuick
import QtQml.Models

QtObject {
    id: root
    required property var backend
    readonly property bool available: backend.available
    readonly property var adapters: available ? backend.adapters.slice().sort((a, b) => a.adapterId.localeCompare(b.adapterId)) : []
    property var adapter: null
    readonly property bool radioEnabled: available && !!adapter && !!adapter.enabled
    // BluetoothAdapterState.Blocked in Quickshell 0.3.1.
    readonly property bool blocked: !!adapter && adapter.state === 4
    readonly property var devices: adapter && available ? adapter.devices.values.filter(device => device.paired) : []
    readonly property int connectedCount: radioEnabled ? devices.filter(device => device.connected).length : 0
    readonly property ListModel deviceModel: ListModel {}
    readonly property bool busy: pending !== null
    readonly property bool canRequest: available && !!adapter && !busy && !backend.busy
    readonly property bool canConnect: canRequest && radioEnabled && !blocked
    readonly property string statusText: !available ? (backend.lastError || qsTr("BlueZ niedostępny"))
        : !adapter ? qsTr("Brak adaptera Bluetooth") : blocked ? qsTr("Bluetooth zablokowany")
        : radioEnabled ? qsTr("Bluetooth włączony") : qsTr("Bluetooth wyłączony")
    readonly property string pendingText: pending ? (pending.kind === "radio" ? qsTr("Zmiana radia")
        : pending.value ? qsTr("Łączenie") : qsTr("Rozłączanie")) + " · " + label(pending.target) + "…" : ""
    property string lastError: ""
    property var pending: null
    property int serial: 0
    property int selectionRevision: 0
    property int actionTimeout: 30000
    property int radioTimeout: 5000
    property bool acknowledged: false

    function label(object: var): string {
        return object ? String(object.name || object.address || object.adapterId || qsTr("Urządzenie bez nazwy")).replace(/[\r\n\t\u2028\u2029]/g, " ") : "";
    }
    function adapterLabel(object: var): string {
        return object ? label(object) + " · " + object.adapterId : "";
    }
    function batteryText(device: var): string {
        return device && device.batteryAvailable && Number.isFinite(device.battery)
            ? qsTr("Bateria urządzenia · ") + Math.round(Math.max(0, Math.min(1, device.battery)) * 100) + "%" : "";
    }
    function deviceStatus(device: var): string {
        if (!device || !device.paired) return qsTr("Urządzenie niedostępne");
        if (pending && pending.target === device)
            return pending.value ? qsTr("Łączenie…") : qsTr("Rozłączanie…");
        return device.blocked ? qsTr("Zablokowane · otwórz menedżer")
            : !radioEnabled ? qsTr("Radio wyłączone")
            : device.connected ? qsTr("Połączono · Enter rozłącza") : qsTr("Sparowane · Enter łączy");
    }
    function selectAdapter(value: var): bool {
        if (adapters.indexOf(value) < 0 || adapter === value) return false;
        adapter = value;
        return true;
    }
    function syncAdapters(): void {
        // Retain the choice across hotplug/power changes. On loss choose the
        // lexicographically first hci ID, never whichever becomes powered.
        if (adapters.indexOf(adapter) < 0) adapter = adapters.length ? adapters[0] : null;
        validatePending();
    }
    function syncDevices(): void {
        // Incremental model updates retain delegates and keyboard focus.
        for (let i = deviceModel.count - 1; i >= 0; --i)
            if (devices.indexOf(deviceModel.get(i).device) < 0) deviceModel.remove(i);
        for (let i = 0; i < devices.length; ++i) {
            let found = -1;
            for (let j = i; j < deviceModel.count; ++j)
                if (deviceModel.get(j).device === devices[i]) { found = j; break; }
            if (found < 0) deviceModel.insert(i, {device: devices[i]});
            else if (found !== i) deviceModel.move(found, i, 1);
        }
        validatePending();
    }
    function start(kind: string, target: var, value: bool): bool {
        if (!canRequest) return false;
        const operation = ++serial;
        lastError = "";
        acknowledged = false;
        pending = {id: operation, kind: kind, target: target, value: value, adapter: adapter, selection: selectionRevision};
        deadline.interval = kind === "radio" ? radioTimeout : actionTimeout;
        deadline.restart();
        if (!backend.request(kind, target, value, operation)) {
            finish(qsTr("Operacja Bluetooth niedostępna"));
            return false;
        }
        return true;
    }
    function setEnabled(value: bool): bool {
        if (!canRequest || (value && blocked)) return false;
        if (value === radioEnabled) return true;
        return start("radio", adapter, value);
    }
    function activate(device: var): bool {
        if (!canConnect || devices.indexOf(device) < 0 || device.blocked) return false;
        return start("device", device, !device.connected);
    }
    function finish(error: string): void {
        const old = pending;
        pending = null;
        deadline.stop();
        acknowledged = false;
        if (old && old.selection === selectionRevision) lastError = error;
    }
    function invalidate(error: string): void {
        if (!pending) return;
        const id = pending.id;
        finish(error);
        backend.cancel(id);
    }
    function validatePending(): void {
        if (!pending) return;
        const a = pending.adapter;
        if (!available || !a || adapters.indexOf(a) < 0
            || (pending.kind === "device" && (!a.enabled || !pending.target || !pending.target.paired || a.devices.values.indexOf(pending.target) < 0)))
            invalidate(qsTr("Wybrane urządzenie lub adapter jest już niedostępny"));
    }
    function observe(): void {
        validatePending();
        if (!pending || !acknowledged) return;
        const actual = pending.kind === "radio" ? pending.target.enabled : pending.target.connected;
        if (actual === pending.value) finish("");
    }
    function openManager(): void { backend.openManager(); }

    onAdaptersChanged: syncAdapters()
    onDevicesChanged: syncDevices()
    onAdapterChanged: { selectionRevision++; lastError = ""; }
    readonly property Connections results: Connections {
        target: root.backend
        function onCompleted(serial: int, error: string): void {
            if (!root.pending || root.pending.id !== serial) return;
            if (error) root.finish(error);
            else { root.acknowledged = true; root.observe(); }
        }
    }
    readonly property Connections radioChanges: Connections {
        target: root.pending ? root.pending.adapter : null
        function onEnabledChanged(): void { root.observe(); }
    }
    readonly property Connections deviceChanges: Connections {
        target: root.pending && root.pending.kind === "device" ? root.pending.target : null
        function onConnectedChanged(): void { root.observe(); }
        function onPairedChanged(): void { root.validatePending(); }
    }
    readonly property Connections deviceListChanges: Connections {
        target: root.pending && root.pending.adapter ? root.pending.adapter.devices : null
        function onValuesChanged(): void { root.validatePending(); }
    }
    readonly property Timer deadline: Timer {
        onTriggered: root.invalidate(qsTr("Nie potwierdzono operacji Bluetooth w wymaganym czasie"))
    }
    Component.onCompleted: { syncAdapters(); syncDevices(); }
    Component.onDestruction: { if (pending) backend.cancel(pending.id); }
}
