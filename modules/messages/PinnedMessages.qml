pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var adapter
    readonly property var pins: adapter && adapter.selectedConversation ? adapter.selectedConversation.pinnedMessages || [] : []
    visible: pins.length > 0
    spacing: Metrics.space4
    Repeater {
        id: buttons
        model: root.pins
        delegate: UI.NavigationButton {
            id: button
            required property var modelData
            required property int index
            objectName: "pinnedMessage"
            width: root.width
            text: modelData.text || qsTr("Załącznik")
            tooltip: ""
            Accessible.name: qsTr("Przypięta wiadomość: ") + text
            upTarget: index > 0 ? buttons.itemAt(index - 1) : null
            downTarget: index + 1 < buttons.count ? buttons.itemAt(index + 1) : null
            contentItem: Text {
                text: qsTr("Przypięto · ") + button.text
                font: button.font; color: button.foreground
                elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; textFormat: Text.PlainText
            }
            onClicked: root.adapter.jumpTo(modelData.messageId)
        }
    }
}
