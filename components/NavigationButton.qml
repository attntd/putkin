import QtQuick

Button {
    id: root
    property Item leftTarget: null
    property Item rightTarget: null
    property Item upTarget: null
    property Item downTarget: null
    property bool hasDetails: false
    signal ensureVisible(Item item)
    signal detailsRequested()

    KeyNavigation.left: leftTarget
    KeyNavigation.right: rightTarget
    KeyNavigation.up: upTarget
    KeyNavigation.down: downTarget
    onActiveFocusChanged: { if (activeFocus) ensureVisible(root); }

    function move(direction: string): void {
        let next = root[direction];
        const visited = [root];
        while (next && visited.indexOf(next) < 0) {
            if (next.enabled && next.visible) {
                next.forceActiveFocus(Qt.TabFocusReason);
                return;
            }
            visited.push(next);
            next = next[direction];
        }
    }

    // Installed on buttons only: text editors keep all their letters.
    Keys.onPressed: event => {
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier)
            return;
        if (event.key === Qt.Key_H)
            move("leftTarget");
        else if (event.key === Qt.Key_L)
            move("rightTarget");
        else if (event.key === Qt.Key_J)
            move("downTarget");
        else if (event.key === Qt.Key_K)
            move("upTarget");
        else if (event.key === Qt.Key_I && root.hasDetails) {
            if (!event.isAutoRepeat) root.detailsRequested();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat)
                root.click();
        } else
            return;
        event.accepted = true;
    }
}
