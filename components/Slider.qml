import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"

Controls.Slider {
    id: root

    required property string accessibleName
    property color fillColor: Theme.accent
    property bool drawFocus: true
    property string tooltip: accessibleName + ": " + Math.round(value)

    implicitWidth: horizontal ? 240 : Metrics.controlHeight
    implicitHeight: horizontal ? Metrics.controlHeight : 240
    padding: Metrics.space8
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: accessibleName
    Keys.forwardTo: [input]
    ControlInput { id: input; control: root }

    background: Item {
        Rectangle {
            x: root.horizontal ? root.leftPadding : (root.width - width) / 2
            y: root.horizontal ? (root.height - height) / 2 : root.topPadding
            width: root.horizontal ? root.availableWidth : Metrics.space4
            height: root.horizontal ? Metrics.space4 : root.availableHeight
            color: Theme.border
            radius: Metrics.radius

            AccentRectangle {
                x: root.horizontal && root.mirrored ? parent.width - width : 0
                y: root.vertical ? parent.height - height : 0
                width: root.horizontal ? root.position * parent.width : parent.width
                height: root.horizontal ? parent.height : root.position * parent.height
                color: root.enabled ? root.fillColor : Theme.textDisabled
                radius: Metrics.radius
                accentFill: root.enabled
            }
        }
        FocusIndicator { control: root; shown: root.drawFocus }
    }
    handle: Rectangle {
        id: knob
        x: root.horizontal ? root.leftPadding + root.visualPosition * (root.availableWidth - width) : (root.width - width) / 2
        y: root.horizontal ? (root.height - height) / 2 : root.topPadding + root.visualPosition * (root.availableHeight - height)
        implicitWidth: Metrics.space12
        implicitHeight: Metrics.space12
        color: !root.enabled ? Theme.textDisabled : root.pressed ? Theme.text : knobAccent.color
        AccentCoordinates { id: knobAccent; item: knob }
        radius: width / 2
        border.color: Theme.backgroundStrong
        border.width: Metrics.borderWidth
    }
}
