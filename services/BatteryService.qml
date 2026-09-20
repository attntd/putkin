import QtQml

QtObject {
    id: root
    required property var backend
    // UPower's DisplayDevice is the system aggregate, never a peripheral.
    readonly property var device: backend.device
    readonly property bool available: backend.available
    readonly property bool present: available && device !== null && device.ready
        && device.isPresent && device.isLaptopBattery
    // Quickshell 0.3.1 converts UPower's 0..100 wire value to 0..1.
    readonly property int percentage: present && Number.isFinite(device.percentage)
        && device.percentage >= 0 && device.percentage <= 1 ? Math.round(device.percentage * 100) : -1
    readonly property int state: present ? device.state : 0
    readonly property bool charging: state === 1
    readonly property bool discharging: state === 2 || state === 3 || state === 6
    readonly property int warningLevel: present && discharging && percentage >= 0
        ? (percentage <= 5 ? 2 : percentage <= 20 ? 1 : 0) : 0
    readonly property string warningText: warningLevel === 2 ? qsTr("Bateria krytycznie niska")
        : warningLevel === 1 ? qsTr("Niski poziom baterii") : ""
    readonly property string stateText: !available ? qsTr("Bateria — usługa niedostępna")
        : !present ? qsTr("Brak baterii komputera")
        : state === 1 ? qsTr("Ładowanie") : state === 2 ? qsTr("Na baterii")
        : state === 3 ? qsTr("Rozładowana") : state === 4 ? qsTr("Naładowana")
        : state === 5 ? qsTr("Oczekuje na ładowanie") : state === 6 ? qsTr("Oczekuje na rozładowanie")
        : qsTr("Stan baterii nieznany")
    readonly property string timeText: !present ? "" : charging ? duration(device.timeToFull, true)
        : state === 2 ? duration(device.timeToEmpty, false) : ""
    readonly property string percentageText: percentage >= 0 ? percentage + "%" : "—"
    readonly property string statusText: (present ? percentageText + " · " : "") + stateText
        + (timeText ? " · " + timeText : "") + (warningText ? " · " + warningText : "")

    function duration(seconds: real, toFull: bool): string {
        if (!Number.isFinite(seconds) || seconds <= 0) return "";
        const minutes = Math.max(1, Math.round(seconds / 60));
        const hours = Math.floor(minutes / 60);
        const value = hours > 0 ? qsTr("%1 h %2 min").arg(hours).arg(minutes % 60) : qsTr("%1 min").arg(minutes);
        return toFull ? qsTr("do pełna: %1").arg(value) : qsTr("pozostało: %1").arg(value);
    }
}
