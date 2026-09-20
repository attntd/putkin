import QtQuick

QtObject {
    property string name: "Bluetooth laptopa"
    property string adapterId: "hci0"
    readonly property string dbusPath: "/org/bluez/" + adapterId
    property bool enabled: true
    property int state: enabled ? 1 : 0
    property bool discovering: false
    property int discoveryChanges: 0
    onDiscoveringChanged: discoveryChanges++
    readonly property MockObjectModel devices: MockObjectModel {}
}
