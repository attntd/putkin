import QtQuick

QtObject {
    property var adapter: null
    property string name: "Słuchawki"
    property string address: "00:11:22:33:44:55"
    readonly property string dbusPath: adapter ? adapter.dbusPath + "/dev_" + address.replace(/:/g, "_") : ""
    property bool paired: true
    property bool connected: false
    property bool blocked: false
    property bool batteryAvailable: false
    property real battery: 0.72
}
