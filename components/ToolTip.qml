import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"

Controls.ToolTip {
    id: root

    delay: Metrics.tooltipDelay
    padding: Metrics.space8
    width: Math.min(implicitWidth, Metrics.panelWidth, parent && parent.Window.window
        ? Math.max(1, parent.Window.window.width - Metrics.space16) : Metrics.panelWidth)
    font.family: Theme.fontFamily
    font.pixelSize: Metrics.smallFontSize
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font: root.font
        color: Theme.text
    }
    background: Rectangle {
        color: Theme.backgroundStrong
        radius: Metrics.radius
        border.width: Metrics.borderWidth
        border.color: Theme.border
    }
    enter: Transition {}
    exit: Transition {}
}
