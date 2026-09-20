import QtQuick

QtObject {
    id: root
    required property var backend
    property bool isInput: false
    readonly property var devices: backend.ready ? backend.devices : []
    readonly property var defaultDevice: backend.ready ? backend.defaultDevice : null
    readonly property var state: backend.snapshot
    readonly property bool available: backend.ready && defaultDevice !== null && state !== null
        && state.node === defaultDevice && devices.indexOf(defaultDevice) >= 0
    // Unavailable is not 0%. External amplification is displayed honestly;
    // commands issued by Putkin are limited to 0–100%.
    readonly property real volume: available ? state.volume * 100 : -1
    readonly property bool muted: available && state.muted
    readonly property string deviceName: defaultDevice ? label(defaultDevice) : ""
    readonly property string statusText: !backend.ready ? qsTr("Audio niedostępne")
        : !defaultDevice ? (isInput ? qsTr("Brak wejścia audio") : qsTr("Brak wyjścia audio"))
        : !available ? qsTr("Odczytywanie urządzenia…")
        : muted ? qsTr("Wyciszone · %1%").arg(Math.round(volume)) : Math.round(volume) + "%"
    property string lastError: ""
    property var pending: null
    readonly property bool busy: pending !== null
    property int operationTimeout: 1800
    property var previous: null
    signal feedback(string monitor)

    function baseLabel(node: var): string {
        const name = String(node.name || "");
        const description = String(node.description || "");
        const nickname = String(node.nickname || "");
        const details = name + " " + nickname + " " + description;
        const builtIn = /^alsa_(output|input)\.(pci|platform)[-_.]/i.test(name);
        const hdmi = details.match(/HDMI(?:[ _/]*(?:DisplayPort)?[ _]*)?(\d+)/i);
        if (hdmi) return qsTr("HDMI / DisplayPort %1").arg(hdmi[1] || "1");
        const hdmiProfile = name.match(/hdmi-stereo(?:-extra(\d+))?/i);
        if (hdmiProfile) return qsTr("HDMI / DisplayPort %1").arg(Number(hdmiProfile[1] || 0) + 1);
        if (builtIn && !isInput && /speaker/i.test(details)) return qsTr("Wbudowane głośniki");
        if (builtIn && !isInput && /headphone/i.test(details)) return qsTr("Słuchawki");
        if (builtIn && isInput && /mic/i.test(details)) return qsTr("Wbudowany mikrofon");
        return nickname || description || name || (isInput ? qsTr("Wejście audio") : qsTr("Wyjście audio"));
    }
    function label(node: var): string {
        const base = baseLabel(node);
        const same = devices.filter(value => baseLabel(value) === base);
        if (same.length < 2) return base;
        same.sort((a, b) => String(a.name).localeCompare(String(b.name)));
        return base + " · " + (same.indexOf(node) + 1);
    }
    function reject(message: string): bool { lastError = message; return false; }
    function validNumber(value: var): bool { return typeof value === "number" && isFinite(value); }

    function setVolume(value: var, monitor: string): bool {
        if (!validNumber(value) || value < 0 || value > 100)
            return reject(qsTr("Głośność musi być liczbą od 0 do 100."));
        return requestLevel("volume", value / 100, monitor);
    }
    function changeVolume(delta: var, monitor: string): bool {
        if (!validNumber(delta) || Math.abs(delta) > 100)
            return reject(qsTr("Zmiana głośności musi być liczbą od −100 do 100."));
        const base = pending && pending.kind === "level" && pending.volume !== null ? pending.volume * 100 : volume;
        return setVolume(Math.max(0, Math.min(100, base + delta)), monitor);
    }
    function setMuted(value: var, monitor: string): bool {
        if (typeof value !== "boolean") return reject(qsTr("Niepoprawny stan wyciszenia."));
        return requestLevel("muted", value, monitor);
    }
    function toggleMute(monitor: string): bool {
        const base = pending && pending.kind === "level" && pending.muted !== null ? pending.muted : muted;
        return setMuted(!base, monitor);
    }
    function requestLevel(field: string, value: var, monitor: string): bool {
        if (!available) return reject(qsTr("Urządzenie audio jest niedostępne."));
        if (pending && pending.kind === "device") return reject(qsTr("Trwa zmiana urządzenia audio."));
        const request = pending && pending.node === defaultDevice
            ? Object.assign({}, pending) : { kind: "level", node: defaultDevice, volume: null, muted: null };
        request[field] = value;
        request.monitor = monitor;
        pending = request;
        lastError = "";
        deadline.restart();
        const accepted = field === "volume" ? backend.writeVolume(request.node, value) : backend.writeMuted(request.node, value);
        if (!accepted) {
            fail(qsTr("Nie można zmienić stanu urządzenia audio."));
            return false;
        }
        Qt.callLater(sync);
        return true;
    }
    function selectDevice(node: var, monitor: string): bool {
        if (!backend.ready || devices.indexOf(node) < 0)
            return reject(qsTr("Wybrane urządzenie nie jest już dostępne."));
        pending = { kind: "device", node: node, monitor: monitor };
        lastError = "";
        deadline.restart();
        if (!backend.selectDevice(node)) {
            fail(qsTr("Nie można wybrać urządzenia audio."));
            return false;
        }
        Qt.callLater(sync);
        return true;
    }
    function fail(message: string): void {
        deadline.stop();
        pending = null;
        lastError = message;
    }
    function sync(): void {
        const current = available ? state : null;
        let notified = false;
        if (pending) {
            if (!backend.ready || devices.indexOf(pending.node) < 0
                    || (pending.kind === "level" && pending.node !== defaultDevice)) {
                fail(qsTr("Urządzenie audio zniknęło lub zostało zmienione."));
            } else if (current && pending.node === current.node && !backend.refreshing
                    && (pending.kind === "device" || ((pending.volume === null || Math.abs(current.volume - pending.volume) < 0.005)
                        && (pending.muted === null || pending.muted === current.muted)))) {
                const monitor = pending.monitor;
                deadline.stop();
                pending = null;
                lastError = "";
                feedback(monitor);
                notified = true;
            }
        }
        // First sample, reconnect, and a new default output establish a baseline.
        if (!notified && !pending && current && previous && previous.node === current.node
                && (Math.abs(previous.volume - current.volume) > 0.0001 || previous.muted !== current.muted))
            feedback("");
        previous = current;
    }
    readonly property Timer deadline: Timer {
        interval: root.operationTimeout
        onTriggered: root.fail(qsTr("Backend nie potwierdził zmiany audio. Spróbuj ponownie."))
    }
    readonly property Connections changes: Connections {
        target: root.backend
        function onSnapshotChanged(): void { Qt.callLater(root.sync); }
        function onReadyChanged(): void { Qt.callLater(root.sync); }
        function onDefaultDeviceChanged(): void { Qt.callLater(root.sync); }
        function onDevicesChanged(): void { Qt.callLater(root.sync); }
        function onRefreshingChanged(): void { Qt.callLater(root.sync); }
    }
    Component.onCompleted: Qt.callLater(sync)
}
