pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../components" as UI
import "../../assets/signal/Paths.js" as SignalIcons

FocusScope {
    id: root
    required property var message
    required property var history
    property bool revealed: false
    readonly property bool showing: revealed || activeFocus || history.actionsMessageId === message.messageId
    implicitWidth: 3 * 32
    implicitHeight: 32
    width: implicitWidth
    height: implicitHeight
    opacity: showing ? 1 : 0
    // The Tab chain can reveal the toolbar even while the pointer is elsewhere.
    component Action: UI.NavigationButton {
        id: button
        required property string symbol
        width: 32; height: 32
        padding: 4
        tooltip: ""
        enabled: root.history.readingEnabled
        background: Rectangle {
            radius: Metrics.radius
            color: button.down ? Theme.border : button.hovered ? Theme.surfaceHover : "transparent"
            UI.FocusIndicator { control: button }
        }
        contentItem: UI.Glyph { symbol: button.symbol; iconCatalog: SignalIcons.icons; color: button.foreground }
        onEnsureVisible: item => root.history.revealControl(item)
    }
    Row {
        anchors.fill: parent
        Action {
            id: react
            objectName: "reactMessage"
            symbol: "react"
            text: qsTr("Reakcja")
            enabled: root.history.readingEnabled && root.message.canReact
            rightTarget: reply; upTarget: root.history; downTarget: root.history
            onClicked: root.history.showActions(root.message.messageId, react, focusReason, "reactions")
        }
        Action {
            id: reply
            objectName: "replyMessage"
            symbol: "reply"
            text: qsTr("Odpowiedz")
            enabled: root.history.readingEnabled && root.message.canReply
            leftTarget: react; rightTarget: more; upTarget: root.history; downTarget: root.history
            onClicked: root.history.adapter.replyTo(root.message.messageId)
        }
        Action {
            id: more
            objectName: "messageActions"
            symbol: "more"
            text: qsTr("Akcje wiadomości")
            leftTarget: reply; upTarget: root.history; downTarget: root.history
            onClicked: root.history.showActions(root.message.messageId, more, focusReason, "menu")
        }
    }
}
