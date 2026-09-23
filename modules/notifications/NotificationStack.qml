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
    property Item focusedCard: null
    property int focusedIndex: 0
    property var navigationCards: []
    property int nextRow: 0
    readonly property bool navigating: controller.screenName === screenName
    enabled: shown
    readonly property int count: navigationCards.length
    readonly property real cardHeightLimit: (availableHeight - Math.max(0, cards.count - 1) * Metrics.panelGap) / Math.max(1, cards.count)
    implicitHeight: column.implicitHeight
    function cardAt(index: int): Item { return index >= 0 && index < count ? navigationCards[index] : null; }
    function rebuildNavigation(): void {
        const items = [];
        for (let i = 0; i < cards.count; ++i) {
            const card = cards.itemAt(i);
            if (card && card.shown) items.push(card);
        }
        navigationCards = items;
        const selectedIndex = items.indexOf(focusedCard);
        if (selectedIndex >= 0) focusedIndex = selectedIndex;
        if (navigating && count) Qt.callLater(recoverFocus);
    }
    function rememberFocusReason(): void {
        if (!navigating || !focusedControl || !focusedControl.activeFocus) return;
        const reason = focusedControl.focusReason;
        if (reason === Qt.MouseFocusReason || reason === Qt.TabFocusReason
                || reason === Qt.BacktabFocusReason || reason === Qt.ShortcutFocusReason)
            controller.focusReason = reason;
    }
    function recoverFocus(): void {
        if (!navigating || !count) return;
        if (focusedCard && navigationCards.indexOf(focusedCard) >= 0 && focusedControl && focusedControl.activeFocus && focusedControl.enabled) {
            focusedControl.focusReason = controller.focusReason;
            return;
        }
        const reason = controller.focusReason;
        const control = cardAt(Math.min(focusedIndex, count - 1)).selectionControl;
        control.forceActiveFocus(reason);
        control.focusReason = reason;
    }
    function focusInitial(): void {
        if (!navigating || count === 0) return;
        for (let i = 0; i < count; ++i) {
            const card = cardAt(i);
            if (card.entry && card.entry.historyKey === controller.replyHistoryKey && card.replySession) {
                card.focusReply(controller.focusReason); return;
            }
        }
        cardAt(0).selectionControl.forceActiveFocus(controller.focusReason);
    }
    function sync(): void {
        const values = service.visibleOn(screenName);
        for (let index = list.count - 1; index >= 0; index--) {
            const old = list.get(index);
            if (!old.leaving && values.indexOf(old.entry) < 0) {
                const snapshot = Object.assign({}, old.entry.closedSnapshot || old.entry.snapshot());
                // Internal cards render their current session-history record,
                // so the fade never retains another copy of message content.
                if (snapshot.messageReference) { snapshot.summary = ""; snapshot.body = ""; }
                list.setProperty(index, "snapshot", JSON.stringify(snapshot));
                list.setProperty(index, "leaving", true);
            }
        }
        values.forEach((entry, index) => {
            let found = -1;
            for (let row = 0; row < list.count; row++) if (list.get(row).entry === entry) found = row;
            if (found < 0) list.insert(index, {entry: entry, leaving: false, snapshot: "", rowKey: nextRow++});
            else {
                if (list.get(found).leaving) {
                    list.setProperty(found, "leaving", false);
                    list.setProperty(found, "snapshot", "");
                }
                if (found !== index) list.move(found, index, 1);
            }
        });
        rebuildNavigation();
    }
    function prune(rowKey: int): void {
        for (let index = list.count - 1; index >= 0; index--)
            if (list.get(index).rowKey === rowKey) list.remove(index);
        rebuildNavigation();
    }
    onNavigatingChanged: {
        if (navigating) Qt.callLater(focusInitial);
        else { focus = false; focusedControl = null; focusedCard = null; focusedIndex = 0; }
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
                service: root.service
                toast: true
                shown: !model.leaving
                width: column.width
                height: Math.min(implicitHeight, root.cardHeightLimit)
                navigating: root.navigating
                readonly property int navigationIndex: root.navigationCards.indexOf(card)
                previousControl: root.cardAt(navigationIndex - 1) ? root.cardAt(navigationIndex - 1).selectionControl : null
                nextControl: navigationIndex >= 0 && root.cardAt(navigationIndex + 1) ? root.cardAt(navigationIndex + 1).selectionControl : null
                onControlFocused: item => {
                    root.focusedControl = item; root.focusedCard = card;
                    root.focusedIndex = Math.max(0, navigationIndex);
                    root.rememberFocusReason();
                }
                onDismissRequested: root.service.dismissHistory(entry.historyKey)
                onArchiveRequested: root.service.expire(entry)
                onActionRequested: identifier => {
                    if (entry && entry.messageReference && identifier !== "open") {
                        if (identifier === "reply") {
                            if (root.controller.enterReply(entry, Qt.TabFocusReason)) card.focusReply(Qt.TabFocusReason);
                        } else root.service.invoke(entry, identifier);
                        return;
                    }
                    const historyKey = entry.historyKey;
                    const navigating = root.navigating;
                    root.controller.close();
                    if (!root.service.invokeHistory(historyKey, identifier) && navigating) root.controller.enter();
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
    Connections {
        target: root.focusedControl
        function onFocusReasonChanged(): void { root.rememberFocusReason(); }
    }
    Connections { target: root.controller; function onEntered(name: string): void { if (name === root.screenName) Qt.callLater(root.focusInitial); } }
    Component.onCompleted: sync()
}
