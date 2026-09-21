pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

UI.FadeScope {
    id: root
    required property var service
    required property var controller
    required property string screenName
    required property real availableHeight
    property Item focusedControl: null
    property int nextRow: 0
    readonly property bool navigating: controller.screenName === screenName
    enabled: shown
    readonly property int count: cards.count
    readonly property real cardHeightLimit: (availableHeight - Math.max(0, count - 1) * Metrics.panelGap) / Math.max(1, count)
    implicitHeight: column.implicitHeight
    function cardAt(index: int): Item { return cards.itemAt(index); }
    function focusInitial(): void { if (navigating && cards.count > 0) cards.itemAt(0).selectionControl.forceActiveFocus(controller.focusReason); }
    function sync(): void {
        const values = service.visibleOn(screenName);
        for (let index = list.count - 1; index >= 0; index--) {
            const old = list.get(index);
            if (!old.leaving && values.indexOf(old.entry) < 0) {
                list.setProperty(index, "snapshot", JSON.stringify(old.entry.closedSnapshot || old.entry.snapshot()));
                list.setProperty(index, "leaving", true);
            }
        }
        values.forEach((entry, index) => {
            let found = -1;
            for (let row = 0; row < list.count; row++) if (list.get(row).entry === entry) found = row;
            if (found < 0) list.insert(index, {entry: entry, leaving: false, snapshot: "", rowKey: nextRow++});
            else if (found !== index) list.move(found, index, 1);
        });
        if (navigating && (!focusedControl || !focusedControl.activeFocus)) Qt.callLater(focusInitial);
    }
    function prune(rowKey: int): void {
        for (let index = list.count - 1; index >= 0; index--)
            if (list.get(index).rowKey === rowKey) list.remove(index);
    }
    onNavigatingChanged: {
        if (navigating) Qt.callLater(focusInitial);
        else { focus = false; focusedControl = null; }
    }
    Keys.onPressed: event => {
        if (DismissKeys.matches(event, root)) {
            controller.close();
            event.accepted = true;
        }
    }
    ListModel { id: list }
    Column {
        id: column
        width: parent.width
        spacing: Metrics.panelGap
        Repeater {
            id: cards
            model: list
            delegate: NotificationCard {
                id: card
                required property int index
                required property var model
                entry: model.leaving ? JSON.parse(model.snapshot) : model.entry
                shown: !model.leaving
                width: column.width
                height: Math.min(implicitHeight, root.cardHeightLimit)
                navigating: root.navigating
                previousControl: index > 0 && root.cardAt(index - 1) ? root.cardAt(index - 1).selectionControl : null
                nextControl: index + 1 < root.count && root.cardAt(index + 1) ? root.cardAt(index + 1).selectionControl : null
                onControlFocused: item => root.focusedControl = item
                onDismissRequested: root.service.dismiss(entry)
                onActionRequested: identifier => {
                    root.controller.close();
                    root.service.invoke(entry, identifier);
                }
                Timer {
                    interval: Metrics.panelFade
                    running: card.model.leaving
                    onTriggered: root.prune(card.model.rowKey)
                }
            }
        }
    }
    Connections { target: root.service; function onChanged(): void { root.sync(); } }
    Connections { target: root.controller; function onEntered(name: string): void { if (name === root.screenName) Qt.callLater(root.focusInitial); } }
    Component.onCompleted: sync()
}
