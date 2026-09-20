import QtQuick

Column {
    id: root
    required property var network
    readonly property alias networkSection: section
    signal requested(string surface)
    signal dismissed()
    signal ensureVisible(Item item)
    function focusInitial(reason = Qt.TabFocusReason): void { section.firstControl.forceActiveFocus(reason); }
    function dismissOrCollapse(): void { if (network.target) section.collapse(); else dismissed(); }
    NetworkSection {
        id: section
        width: parent.width
        network: root.network
        expanded: true
        previousControl: lastControl
        nextControl: firstControl
        onEnsureVisible: item => root.ensureVisible(item)
    }
}
