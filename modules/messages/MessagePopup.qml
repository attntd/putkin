pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Controls.Popup {
    id: root
    property Item trigger: null
    property Item anchorItem: trigger
    property int reason: Qt.MouseFocusReason
    property bool returnFocus: true
    property bool closing: false
    property real preferredWidth: 250
    property bool preferAbove: false
    parent: Controls.Overlay.overlay
    padding: Metrics.space8
    width: Math.min(preferredWidth, parent ? Math.max(1, parent.width - 16) : preferredWidth)
    height: Math.min(implicitHeight, parent ? Math.max(1, parent.height - 16) : implicitHeight)
    x: {
        const p = anchorItem && parent ? anchorItem.mapToItem(parent, 0, 0) : Qt.point(8, 8);
        return Math.max(8, Math.min(p.x, parent ? parent.width - width - 8 : 8));
    }
    y: {
        const p = anchorItem && parent ? anchorItem.mapToItem(parent, 0, 0) : Qt.point(8, 8);
        const below = p.y + (anchorItem ? anchorItem.height : 0) + 4;
        if (preferAbove && p.y - height - 4 >= 8) return p.y - height - 4;
        return Math.max(8, Math.min(below + height <= (parent ? parent.height - 8 : 0) ? below : p.y - height - 4,
            parent ? parent.height - height - 8 : 8));
    }
    modal: false
    focus: true
    closePolicy: Controls.Popup.CloseOnPressOutside
    Controls.Overlay.onPressed: { if (visible) returnFocus = false; }
    background: UI.PanelFrame {}
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Metrics.panelFade; easing.type: Easing.InOutQuad } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Metrics.panelFade; easing.type: Easing.InOutQuad } }
    onAboutToShow: { closing = false; contentItem.enabled = true; }
    onAboutToHide: { closing = true; contentItem.enabled = false; }
    function restoreTrigger(): void {
        if (returnFocus && trigger && trigger.visible && trigger.enabled) {
            trigger.forceActiveFocus(reason);
            trigger.focusReason = reason;
        }
    }
    // Qt restores its own popup focus during close. Apply the input reason
    // afterwards so the keyboard frame is not reset to PopupFocusReason.
    onClosed: Qt.callLater(restoreTrigger)
    Connections {
        target: root.parent ? root.parent.Window.window : null
        function onActiveFocusItemChanged(): void {
            // Clicking another control must not take focus back from it.
            let current = root.parent.Window.window.activeFocusItem;
            if (!root.opened || root.closing || !current) return;
            while (current && current !== root.contentItem) current = current.parent;
            if (!current) root.returnFocus = false;
        }
    }
}
