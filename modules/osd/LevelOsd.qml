import QtQuick
import "../../core"
import "../../components" as UI

UI.FadeScope {
    id: root
    readonly property bool accentScope: true
    required property real level
    required property string label
    required property string symbol
    property color fillColor: Theme.accent
    implicitWidth: Metrics.osdWidth
    implicitHeight: Metrics.osdHeight
    Accessible.role: Accessible.Indicator
    Accessible.name: label
    UI.AccentRectangle { anchors.fill: parent; color: Theme.backgroundStrong; border.width: Metrics.borderWidth; border.color: Theme.accentBorder; accentOutline: true }
    UI.Glyph {
        id: icon
        x: Metrics.space16; anchors.verticalCenter: parent.verticalCenter
        section: "osd"
        width: slotSize; height: slotSize
        symbol: root.symbol
    }
    Rectangle {
        x: icon.x + icon.width + Metrics.space16
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, parent.width - x - 68)
        height: Metrics.space12
        color: Theme.border
        UI.AccentRectangle {
            objectName: "osdFill"
            width: parent.width * Math.max(0, Math.min(100, root.level)) / 100
            height: parent.height
            color: root.fillColor
            accentFill: true
        }
    }
    UI.PanelText {
        objectName: "osdValue"
        anchors.right: parent.right; anchors.rightMargin: Metrics.space16
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.level) + "%"
        wrapMode: Text.NoWrap
    }
}
