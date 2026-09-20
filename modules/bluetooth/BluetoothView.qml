import QtQuick

Column {
    id: root
    required property var bluetooth
    readonly property alias bluetoothSection: section
    signal requested(string surface)
    signal dismissed()
    signal handoffRequested()
    signal ensureVisible(Item item)
    function focusInitial(reason = Qt.TabFocusReason): void { section.firstControl.forceActiveFocus(reason); }
    function dismissOrCollapse(): void { dismissed(); }
    BluetoothSection {
        id: section
        width: parent.width
        bluetooth: root.bluetooth
        expanded: true
        previousControl: lastControl
        nextControl: firstControl
        onEnsureVisible: item => root.ensureVisible(item)
        onHandoffRequested: root.handoffRequested()
    }
}
