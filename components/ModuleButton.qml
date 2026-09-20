import QtQuick
import "../core"

NavigationButton {
    id: root
    property string symbol: ""
    property bool arrow: false
    property bool expanded: false
    padding: Metrics.space4
    verticalPadding: Metrics.space4
    contentItem: Item {
        Glyph { id: glyph; width: root.symbol ? slotSize : 0; height: parent.height; symbol: root.symbol; color: root.foreground }
        Text {
            anchors.left: glyph.right; anchors.leftMargin: root.symbol ? Metrics.space8 : 0
            anchors.right: chevron.left; anchors.rightMargin: root.arrow ? Metrics.space4 : 0
            height: parent.height
            text: root.text; textFormat: Text.PlainText; font: root.font
            color: root.enabled ? Theme.text : Theme.textDisabled
            verticalAlignment: Text.AlignVCenter; horizontalAlignment: root.arrow ? Text.AlignRight : Text.AlignLeft
            elide: Text.ElideRight
        }
        Glyph { id: chevron; anchors.right: parent.right; width: root.arrow ? slotSize : 0; height: parent.height; symbol: root.arrow ? root.expanded ? "expand_more" : "chevron_right" : ""; color: Theme.text }
    }
    background: Rectangle {
        color: root.hovered ? Theme.surface : "transparent"
        FocusIndicator { control: root }
    }
}
