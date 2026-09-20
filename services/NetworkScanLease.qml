import QtQuick

QtObject {
    id: root
    required property var network
    property bool active: false
    onActiveChanged: {
        if (network) {
            if (active)
                network.acquireScan(root);
            else
                network.releaseScan(root);
        }
    }
    Component.onCompleted: {
        if (active)
            network.acquireScan(root);
    }
    Component.onDestruction: network.releaseScan(root)
}
