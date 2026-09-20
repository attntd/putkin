import QtQuick
import "../core"

Button {
    id: root

    required property string accessibleName
    required property string symbol

    implicitWidth: Metrics.controlHeight
    padding: Metrics.space4
    text: accessibleName
    tooltip: accessibleName
    Accessible.name: accessibleName

    contentItem: Glyph { symbol: root.symbol; color: root.foreground }
}
