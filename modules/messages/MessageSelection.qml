pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../components" as UI

Flow {
    id: root
    required property var history
    spacing: Metrics.space4
    Text {
        text: qsTr("Zaznaczono: %1").arg(root.history.selectedIds.length)
        height: Metrics.controlHeight; verticalAlignment: Text.AlignVCenter
        color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize
    }
    UI.NavigationButton {
        id: forward
        objectName: "forwardSelection"
        text: qsTr("Przekaż"); tooltip: ""
        enabled: root.history.canForwardSelection
        rightTarget: remove; downTarget: root.history
        onClicked: root.history.selectionAction("forward", forward, focusReason)
    }
    UI.NavigationButton {
        id: remove
        objectName: "deleteSelection"
        text: qsTr("Usuń"); tooltip: ""
        leftTarget: forward; rightTarget: cancel; downTarget: root.history
        onClicked: root.history.selectionAction("delete", remove, focusReason)
    }
    UI.NavigationButton {
        id: cancel
        objectName: "cancelSelection"
        text: qsTr("Anuluj"); tooltip: ""
        leftTarget: remove; downTarget: root.history
        onClicked: { root.history.clearSelection(); root.history.forceActiveFocus(focusReason); }
    }
}
