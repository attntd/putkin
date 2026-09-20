import QtQuick
import QtQuick.Controls.Basic as Controls
import "../core"

Controls.TextField {
    id: root
    property bool invalid: false
    signal ensureVisible(Item item)
    implicitHeight: Metrics.controlHeight
    padding: Metrics.space8
    font.family: Theme.fontFamily
    font.pixelSize: Metrics.fontSize
    color: Theme.text
    selectionColor: accent.color
    selectedTextColor: accent.foreground
    placeholderTextColor: Theme.textMuted
    selectByMouse: true
    Keys.forwardTo: [input]
    ControlInput { id: input; control: root }
    AccentCoordinates { id: accent; item: root }
    onActiveFocusChanged: { if (activeFocus) ensureVisible(root); }
    background: Rectangle {
        color: Theme.background
        border.color: root.invalid ? Theme.error : Theme.border
        border.width: Metrics.borderWidth
        FocusIndicator {
            control: root
            border.color: root.invalid ? Theme.error : Theme.focus
        }
    }
}
