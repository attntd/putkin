import QtQuick
import "../../core"
import "../../core/Icons.js" as Icons
import "../../components" as UI

UI.NavigationButton {
    id: root
    required property var battery
    property bool compact: false
    text: battery ? battery.statusText : ""
    padding: 0
    height: Metrics.barHeight
    implicitWidth: Math.max(Metrics.barStatusReserve, implicitContentWidth)
    width: implicitWidth
    foreground: Theme.text
    fillColor: highlighted ? Theme.accent : hovered ? Theme.surface : Theme.background
    contentItem: UI.Glyph {
        objectName: "batteryIcon"
        section: "bar"
        symbol: Icons.battery(root.battery)
        color: root.foreground
    }
    background: UI.AccentRectangle {
        color: root.fillColor
        accentFill: root.highlighted
        UI.FocusIndicator {
            control: root
            anchors.margins: Metrics.focusWidth
            border.color: root.highlighted ? root.accentTextColor : Theme.focus
        }
    }
}
