import QtQuick
import "../../core"
import "../../components"

FocusScope {
    id: root
    required property var service
    readonly property bool accentScope: true
    readonly property rect box: service.selection
    property point origin: Qt.point(0, 0)
    focus: true

    // Four flat rectangles leave the selection clear without sampling pixels.
    Rectangle { width: root.width; height: root.service.hasSelection ? root.box.y : root.height; color: Theme.screenshotShade }
    Rectangle { y: root.box.y + root.box.height; width: root.width; height: Math.max(0, root.height - y); visible: root.service.hasSelection; color: Theme.screenshotShade }
    Rectangle { y: root.box.y; width: root.box.x; height: root.box.height; color: Theme.screenshotShade }
    Rectangle { x: root.box.x + root.box.width; y: root.box.y; width: Math.max(0, root.width - x); height: root.box.height; color: Theme.screenshotShade }
    AccentRectangle {
        x: root.box.x; y: root.box.y; width: root.box.width; height: root.box.height
        visible: root.service.hasSelection
        color: "transparent"
        border.width: Metrics.borderWidth
        accentOutline: true
    }
    MouseArea {
        objectName: "screenshotSelection"
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        onPressed: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.origin = Qt.point(mouse.x, mouse.y);
            root.service.select(mouse.x, mouse.y, mouse.x, mouse.y);
        }
        onPositionChanged: mouse => {
            if (pressed) root.service.select(root.origin.x, root.origin.y, mouse.x, mouse.y);
        }
        onReleased: mouse => root.service.select(root.origin.x, root.origin.y, mouse.x, mouse.y)
    }
    Keys.onPressed: event => {
        if (event.isAutoRepeat) { event.accepted = true; return; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.service.confirm(false);
        else if (event.key === Qt.Key_W) root.service.confirm(true);
        else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) root.service.close();
        else return;
        event.accepted = true;
    }
}
