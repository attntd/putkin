import QtQuick

QtObject {
    property string lastError: ""
    property string checkError: ""
    property bool autoComplete: true
    property var applied: []
    property int checks: 0
    signal checked(int generation, string error)
    signal reloaded()
    function check(generation: int, rows: var): void { checks++; if (autoComplete) Qt.callLater(() => checked(generation, checkError)); }
    function apply(rows: var): void { applied = JSON.parse(JSON.stringify(rows)); }
}
