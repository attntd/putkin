import QtQuick
import "../core"

Item {
    default property alias controls: row.data
    implicitHeight: Metrics.controlHeight
    Rectangle { anchors.fill: parent; color: Theme.backgroundStrong; border.width: Metrics.borderWidth; border.color: Theme.border }
    Row { id: row; anchors.fill: parent }
}
