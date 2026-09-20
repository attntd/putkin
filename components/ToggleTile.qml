import QtQuick
import "../core"

NavigationButton {
    id: root
    property string symbol: ""
    implicitHeight: Metrics.controlHeight + Metrics.space16
    padding: Metrics.space8
    fillColor: checked ? Theme.accent : down ? Theme.surfaceHover : hovered ? Theme.surface : Theme.backgroundStrong
    contentItem: Item {
        Glyph {
            id: glyph
            section: "tile"
            width: slotSize
            height: parent.height
            symbol: root.symbol
            color: !root.enabled ? Theme.textDisabled : root.checked ? root.accentTextColor : Theme.text
        }
        Text {
            anchors.left: glyph.right
            anchors.leftMargin: Metrics.space8
            anchors.right: parent.right
            height: parent.height
            text: root.text
            textFormat: Text.PlainText
            font: root.font
            color: root.foreground
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
