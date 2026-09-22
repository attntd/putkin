import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"

Controls.ScrollBar {
    id: root
    padding: Metrics.space4 / 2
    implicitWidth: Metrics.space12
    implicitHeight: Metrics.space12
    minimumSize: 0.08
    policy: Controls.ScrollBar.AsNeeded
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    Keys.forwardTo: [input]
    ControlInput { id: input; control: root }
    contentItem: AccentRectangle {
        implicitWidth: Metrics.space8
        implicitHeight: Metrics.space8
        radius: Metrics.radius
        color: root.pressed ? Theme.surface : Theme.border
        accentFill: root.pressed || root.hovered
        opacity: root.size < 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Metrics.panelFade; easing.type: Easing.InOutCubic } }
    }
    background: Rectangle { color: "transparent" }
}
