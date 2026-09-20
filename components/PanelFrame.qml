import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"

Controls.Frame {
    padding: Metrics.space12
    background: Rectangle {
        color: Theme.backgroundStrong
        radius: Metrics.radius
        border.width: Metrics.borderWidth
        border.color: Theme.border
    }
}
