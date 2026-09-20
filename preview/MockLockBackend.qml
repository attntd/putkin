import QtQuick
QtObject {
    property bool locked: false
    property bool secure: false
    property int acquisitions: 0
    property int releases: 0
    signal failed(string message)
    function acquire(): bool { ++acquisitions; locked = true; return true; }
    function release(): void { ++releases; secure = false; locked = false; }
}
