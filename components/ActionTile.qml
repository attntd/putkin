import QtQuick
import "../core"

NavigationButton {
    id: root
    property string symbol: ""
    implicitHeight: 72
    padding: Metrics.space8
    fillColor: down ? Theme.surfaceHover : hovered ? Theme.surface : Theme.backgroundStrong
    contentItem: Column {
        spacing: Metrics.space8
        Glyph { section: "tile"; width: parent.width; height: slotSize; symbol: root.symbol; color: !root.enabled ? Theme.textDisabled : root.checked ? root.accentTextColor : Theme.text }
        Text {
            width: parent.width
            text: root.text; font: root.font; color: root.foreground
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        }
    }
}
