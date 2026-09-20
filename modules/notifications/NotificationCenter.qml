pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var service
    property real maximumHeight: 600
    readonly property alias cards: cards
    property Item focusedControl: null
    property int lastFocusReason: Qt.TabFocusReason
    property bool entered: false
    spacing: Metrics.space12
    signal requested(string surface)
    signal dismissed()
    signal ensureVisible(Item item)
    function focusInitial(reason = Qt.TabFocusReason): void { (dnd.enabled ? dnd : clear).forceActiveFocus(reason); }
    function dismissOrCollapse(): void { dismissed(); }
    function cardAt(index: int): Item { return index >= 0 && index < cards.count ? cards.itemAt(index) : null; }
    function reveal(item: Item): void { focusedControl = item; lastFocusReason = item.focusReason; entered = true; ensureVisible(item); }
    function recoverFocus(): void {
        if (entered && enabled && visible && (!focusedControl || !focusedControl.activeFocus || !focusedControl.enabled || !focusedControl.visible))
            focusInitial(lastFocusReason);
    }
    function sync(): void {
        const values = service.history;
        for (let i = rows.count - 1; i >= 0; --i)
            if (!values.some(value => value.historyKey === rows.get(i).key)) rows.remove(i);
        values.forEach((value, index) => {
            let previous = -1;
            for (let i = 0; i < rows.count; ++i) if (rows.get(i).key === value.historyKey) previous = i;
            if (previous < 0) rows.insert(index, {key: value.historyKey});
            else if (previous !== index) rows.move(previous, index, 1);
        });
    }
    UI.PanelText { width: parent.width; text: qsTr("Powiadomienia"); font.bold: true }
    Row {
        width: parent.width
        spacing: Metrics.space8
        UI.NavigationButton {
            id: dnd
            objectName: "notificationDnd"
            width: Math.max(Metrics.controlHeight, parent.width - clear.width - parent.spacing)
            text: qsTr("Nie przeszkadzać")
            checked: root.service.dnd
            enabled: root.service.available
            rightTarget: clear
            downTarget: root.cardAt(0) ? root.cardAt(0).closeControl : clear
            KeyNavigation.tab: clear; KeyNavigation.backtab: root.cardAt(cards.count - 1) ? root.cardAt(cards.count - 1).closeControl : clear
            onClicked: root.service.dnd = !root.service.dnd
            onEnsureVisible: item => root.reveal(item)
        }
        UI.NavigationButton {
            id: clear
            objectName: "notificationClear"
            width: 92
            text: qsTr("Wyczyść")
            leftTarget: dnd
            downTarget: root.cardAt(0) ? root.cardAt(0).closeControl : dnd
            KeyNavigation.tab: downTarget; KeyNavigation.backtab: dnd
            onClicked: { root.service.clearHistory(); root.focusInitial(focusReason); }
            onEnsureVisible: item => root.reveal(item)
        }
    }
    ListModel { id: rows }
    Repeater {
        id: cards
        model: rows
        NotificationCard {
            id: card
            required property int index
            required property int key
            entry: root.service.historyEntry(key)
            width: root.width
            height: Math.min(implicitHeight, Math.max(96, root.maximumHeight - Metrics.controlHeight - Metrics.space24))
            navigating: true
            previousControl: index > 0 && root.cardAt(index - 1) ? root.cardAt(index - 1).closeControl : dnd.enabled ? dnd : clear
            nextControl: root.cardAt(index + 1) ? root.cardAt(index + 1).closeControl : dnd.enabled ? dnd : clear
            onControlFocused: item => root.reveal(item)
            onDismissRequested: {
                const reason = closeControl.focusReason;
                root.service.dismissHistory(key);
                root.focusInitial(reason);
            }
            onActionRequested: identifier => {
                const value = entry;
                root.dismissed();
                root.service.invoke(value, identifier);
            }
        }
    }
    Connections {
        target: root.service
        function onHistoryChanged(): void { root.sync(); Qt.callLater(root.recoverFocus); }
        function onChanged(): void { Qt.callLater(root.recoverFocus); }
    }
    Connections {
        target: root.focusedControl
        function onFocusReasonChanged(): void { root.lastFocusReason = root.focusedControl.focusReason; }
    }
    Component.onCompleted: sync()
}
