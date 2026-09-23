pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var service
    readonly property alias cards: cards
    property var navigationCards: []
    readonly property Item headerControl: dnd.enabled ? dnd : clear
    property Item focusedControl: null
    property int lastFocusReason: Qt.TabFocusReason
    property bool entered: false
    spacing: Metrics.space12
    signal requested(string surface)
    signal dismissed()
    signal ensureVisible(Item item)
    function focusInitial(reason = Qt.TabFocusReason): void { headerControl.forceActiveFocus(reason); }
    function dismissOrCollapse(): void { dismissed(); }
    function cardAt(index: int): Item { return index >= 0 && index < navigationCards.length ? navigationCards[index] : null; }
    function rebuildNavigation(): void {
        // itemAt() does not notify bindings when a delegate finishes loading.
        const items = [];
        for (let index = 0; index < cards.count; ++index) items.push(cards.itemAt(index));
        navigationCards = items;
    }
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
        rebuildNavigation();
        // Place arriving cards before focus/press handlers can use their bounds.
        forceLayout();
    }
    Row {
        width: parent.width
        height: Metrics.controlHeight
        spacing: Metrics.space8
        UI.PanelText {
            objectName: "notificationHeading"
            width: Math.max(1, parent.width - dnd.width - clear.width - parent.spacing * 2)
            height: parent.height
            text: qsTr("Powiadomienia")
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
        UI.NavigationButton {
            id: dnd
            objectName: "notificationDnd"
            width: Metrics.controlHeight
            padding: 0
            tooltip: ""
            Accessible.name: checked ? qsTr("Wyłącz nie przeszkadzać") : qsTr("Włącz nie przeszkadzać")
            contentItem: UI.Glyph { section: "notification"; symbol: dnd.checked ? "notifications_off" : "notifications"; color: dnd.foreground }
            checked: root.service.dnd
            enabled: root.service.available
            rightTarget: clear
            downTarget: root.cardAt(0) ? root.cardAt(0).selectionControl : null
            KeyNavigation.tab: clear; KeyNavigation.backtab: root.cardAt(cards.count - 1) ? root.cardAt(cards.count - 1).selectionControl : clear
            onClicked: root.service.dnd = !root.service.dnd
            onEnsureVisible: item => root.reveal(item)
        }
        UI.NavigationButton {
            id: clear
            objectName: "notificationClear"
            width: Metrics.controlHeight
            padding: 0
            tooltip: ""
            Accessible.name: qsTr("Wyczyść powiadomienia")
            contentItem: UI.Glyph { section: "notification"; symbol: "delete"; color: clear.foreground }
            leftTarget: dnd
            downTarget: root.cardAt(0) ? root.cardAt(0).selectionControl : null
            KeyNavigation.tab: downTarget || root.headerControl; KeyNavigation.backtab: dnd
            onClicked: { root.service.clearHistory(); root.focusInitial(focusReason); }
            onEnsureVisible: item => root.reveal(item)
        }
    }
    ListModel { id: rows }
    Repeater {
        id: cards
        model: rows
        onItemAdded: root.rebuildNavigation()
        onItemRemoved: Qt.callLater(root.rebuildNavigation)
        NotificationCard {
            id: card
            required property int index
            required property int key
            entry: root.service.historyEntry(key)
            service: root.service
            width: root.width
            height: implicitHeight
            scrollable: false
            navigating: true
            previousControl: index > 0 && root.cardAt(index - 1) ? root.cardAt(index - 1).selectionControl : root.headerControl
            nextControl: root.cardAt(index + 1) ? root.cardAt(index + 1).selectionControl : null
            onControlFocused: item => root.reveal(item)
            onDismissRequested: {
                const reason = root.lastFocusReason;
                const next = nextControl || previousControl || root.headerControl;
                root.service.dismissHistory(key);
                next.forceActiveFocus(reason);
            }
            onActionRequested: identifier => {
                const value = entry;
                if (value && value.messageReference && identifier !== "open") {
                    if (root.service.invoke(value, identifier) && identifier === "reply") card.focusReply(Qt.TabFocusReason);
                    return;
                }
                const historyKey = key;
                root.dismissed();
                root.service.invokeHistory(historyKey, identifier);
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
