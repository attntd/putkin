import QtQuick
import "../core"

AccentRectangle {
    required property var control
    property bool shown: true

    objectName: "focusIndicator"
    anchors.fill: parent
    color: "transparent"
    radius: Metrics.radius
    border.width: Metrics.focusWidth
    border.color: Theme.focus
    accentOutline: border.color === Theme.focus
    // TextField has focusReason but does not inherit Control.visualFocus.
    visible: shown && control.activeFocus && (control.focusReason === Qt.TabFocusReason
        || control.focusReason === Qt.BacktabFocusReason || control.focusReason === Qt.ShortcutFocusReason)
}
