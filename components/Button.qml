import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"

Controls.Button {
    id: root

    property string tooltip: text
    property bool windowedTooltip: false
    property string leadingIcon: ""
    property string trailingIcon: ""
    property string iconSection: "list"
    readonly property color accentColor: accent.color
    readonly property color accentTextColor: accent.foreground
    property bool accentFill: enabled && (highlighted || checked)
    property color foreground: !enabled ? Theme.textDisabled : (highlighted || checked) ? accentTextColor : Theme.text
    property color fillColor: !enabled ? Theme.backgroundStrong : (highlighted || checked) ? Theme.accent : down ? Theme.border : hovered ? Theme.surfaceHover : Theme.surface

    implicitWidth: Math.max(implicitContentWidth + leftPadding + rightPadding, Metrics.controlHeight)
    implicitHeight: Metrics.controlHeight
    padding: Metrics.space12
    // Qt Basic otherwise adds two horizontal pixels even when padding is 0.
    horizontalPadding: padding
    verticalPadding: leadingIcon || trailingIcon ? Metrics.space4 : Math.min(padding, Metrics.space8)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: Theme.fontFamily
    font.pixelSize: Metrics.fontSize
    Accessible.name: text
    Accessible.description: tooltip
    Keys.forwardTo: [input]
    ControlInput { id: input; control: root }
    AccentCoordinates { id: accent; item: root }

    contentItem: IconLabel {
        text: root.text
        leadingIcon: root.leadingIcon
        trailingIcon: root.trailingIcon
        section: root.iconSection
        font: root.font
        color: root.foreground
    }
    background: AccentRectangle {
        radius: Metrics.radius
        color: root.fillColor
        border.width: Metrics.borderWidth
        border.color: root.down ? Theme.text : (root.highlighted || root.checked) ? Theme.accentBorder : Theme.border
        accentFill: root.accentFill
        accentOutline: root.accentFill && !root.down

        FocusIndicator {
            control: root
            anchors.margins: root.highlighted || root.checked ? -Metrics.focusOffset : 0
        }
    }
}
