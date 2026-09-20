import QtQuick

Item {
    id: root
    required property var control

    // Qt does not change the focus reason when the same item keeps focus.
    // Update its visual reason without blurring text fields or consuming input.
    Keys.onPressed: event => {
        control.focusReason = Qt.TabFocusReason;
        event.accepted = false;
    }
    TapHandler {
        parent: root.control
        acceptedButtons: Qt.AllButtons
        gesturePolicy: TapHandler.DragThreshold
        onPressedChanged: { if (pressed) root.control.focusReason = Qt.MouseFocusReason; }
    }
}
