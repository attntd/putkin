import QtQml

QtObject {
    id: root
    property bool available: true
    property var device: battery
    readonly property QtObject battery: QtObject {
        property bool ready: true
        property bool isPresent: true
        property bool isLaptopBattery: true
        property real percentage: 0.72
        property int state: 2
        property real timeToEmpty: 14400
        property real timeToFull: 0
    }
}
