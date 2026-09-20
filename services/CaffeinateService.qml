import QtQuick

QtObject {
    id: root
    required property var backend
    readonly property bool available: backend.available
    readonly property bool busy: backend.busy
    readonly property string mode: backend.mode
    readonly property bool enabled: mode !== "off"
    readonly property string lastError: backend.errorText
    property string selectedMode: "presentation"
    readonly property var modes: [
        {id: "presentation", label: qsTr("Prezentacja")},
        {id: "background", label: qsTr("Praca w tle")}
    ]
    function setEnabled(value: bool): bool { return backend.request(value ? selectedMode : "off"); }
    function setMode(value: string): bool { return modes.some(item => item.id === value) && backend.request(value); }
    onModeChanged: { if (mode !== "off") selectedMode = mode; }
}
