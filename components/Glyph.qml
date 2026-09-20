import QtQuick
import QtQuick.Shapes
import "../core"
import "../assets/material/Paths.js" as Paths

Item {
    id: root
    property string symbol: ""
    property string section: "list"
    property color color: Theme.text
    readonly property var metrics: Metrics.iconSections[section] || Metrics.iconSections.list
    readonly property real iconSize: metrics.size
    readonly property real iconPadding: metrics.padding
    readonly property real iconVerticalPadding: metrics.verticalPadding === undefined ? iconPadding : metrics.verticalPadding
    readonly property real canvasWidth: iconSize * viewBox[2] / viewBox[3]
    readonly property real slotSize: canvasWidth + 2 * iconPadding
    readonly property real slotHeight: iconSize + 2 * iconVerticalPadding
    readonly property real pixelRatio: Screen.devicePixelRatio
    readonly property string renderedSymbol: Paths.icons[symbol] ? symbol : "apps"
    readonly property var vector: Paths.icons[renderedSymbol]
    readonly property var viewBox: vector.viewport || vector.box
    readonly property bool ready: shape.status === Shape.Ready
    readonly property color accentColor: accent.color
    implicitWidth: slotSize
    implicitHeight: slotHeight
    AccentCoordinates { id: accent; item: root }
    Item {
        objectName: "iconCanvas"
        anchors.centerIn: parent
        width: root.canvasWidth
        height: root.iconSize
        visible: root.symbol.length > 0
        Shape {
            id: shape
            // Fit the catalog viewport by height, preserving the SVG path's
            // proportions. Wide symbols receive space instead of shrinking.
            readonly property real ratio: root.iconSize / root.viewBox[3]
            x: -root.viewBox[0] * ratio
            y: -root.viewBox[1] * ratio
            width: root.viewBox[2]
            height: root.viewBox[3]
            scale: ratio
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: root.color
                fillRule: ShapePath.WindingFill
                PathSvg { path: root.vector.path }
            }
        }
    }
}
