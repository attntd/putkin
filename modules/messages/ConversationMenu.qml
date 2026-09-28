pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../core/ConversationRoute.js" as Route
import "../../components" as UI

Item {
    id: root
    required property var hub
    property var route: null
    readonly property var adapter: hub.adapterFor(route)
    readonly property var conversation: adapter ? adapter.conversations.find(c => Route.equal(c.route, route)) || null : null
    readonly property bool opened: popup.visible
    signal detailsRequested(var route, int reason)
    signal actionRequested(int reason)
    readonly property var choices: conversation ? [
        {id: "archiveConversation", label: conversation.archived || conversation.hidden ? qsTr("Przywróć z archiwum") : qsTr("Archiwizuj"), action: "archived", value: !(conversation.archived || conversation.hidden)},
        {id: "pinConversation", label: conversation.pinned ? qsTr("Odepnij rozmowę") : qsTr("Przypnij rozmowę"), action: "pinned", value: !conversation.pinned},
        {id: "readConversation", label: conversation.unreadCount || conversation.markedUnread ? qsTr("Oznacz jako przeczytaną") : qsTr("Oznacz jako nieprzeczytaną"), action: conversation.unreadCount || conversation.markedUnread ? "read" : "markedUnread", value: true},
        {id: "menuMuteConversation", label: conversation.muted ? qsTr("Włącz powiadomienia") : qsTr("Wycisz"), action: "muted", value: !conversation.muted},
        {id: "menuConversationDetails", label: qsTr("Szczegóły rozmowy"), action: "details", value: false}
    ] : []
    function show(address: var, trigger: Item, reason: int): void {
        route = Route.copy(address);
        if (!conversation) return;
        popup.trigger = trigger; popup.reason = reason; popup.returnFocus = true;
        popup.anchorItem = trigger.objectName === "conversationList" ? trigger.currentItem : trigger;
        popup.open();
        Qt.callLater(() => { list.currentIndex = 0; list.forceLayout(); if (list.currentItem) list.currentItem.forceActiveFocus(reason); });
    }
    function activate(option: var, reason: int): void {
        if (!conversation || popup.closing) return;
        popup.reason = reason;
        if (option.action === "details") {
            popup.returnFocus = false; popup.close(); root.detailsRequested(route, reason);
        } else {
            actionRequested(reason);
            if (adapter.manageConversation(route.conversationId, option.action, option.value)) {
                popup.returnFocus = true; popup.closing = true; popup.close();
            }
        }
    }
    function dismiss(): void { popup.close(); }
    function closeFromKeyboard(): void {
        popup.reason = Qt.TabFocusReason; popup.returnFocus = true; popup.closing = true; popup.close();
    }
    onConversationChanged: if (!conversation && opened) { popup.returnFocus = false; popup.close(); }
    MessagePopup {
        id: popup
        objectName: "conversationMenu"
        preferredWidth: 292
        contentItem: ListView {
            id: list
            implicitHeight: count * Metrics.controlHeight
            model: root.choices
            clip: true
            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: UI.ScrollBar {}
            Keys.onEscapePressed: root.closeFromKeyboard()
            delegate: UI.Button {
                id: action
                required property var modelData
                required property int index
                objectName: modelData.id
                width: list.width
                text: modelData.label
                tooltip: ""
                enabled: modelData.action !== "read" || (root.conversation && root.conversation.canRead !== false)
                background: Rectangle {
                    color: action.down ? Theme.border : action.hovered ? Theme.surfaceHover : "transparent"
                    UI.FocusIndicator { control: action }
                }
                onClicked: root.activate(modelData, focusReason)
                Keys.onPressed: event => {
                    if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
                    popup.reason = Qt.TabFocusReason;
                    if ([Qt.Key_H, Qt.Key_Left, Qt.Key_Escape].includes(event.key)) root.closeFromKeyboard();
                    else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_L, Qt.Key_Right].includes(event.key)) {
                        if (!event.isAutoRepeat) root.activate(modelData, Qt.TabFocusReason);
                    } else if ([Qt.Key_J, Qt.Key_Down, Qt.Key_K, Qt.Key_Up].includes(event.key)) {
                        const delta = event.key === Qt.Key_J || event.key === Qt.Key_Down ? 1 : -1;
                        let next = index + delta;
                        if (next >= 0 && next < list.count && root.choices[next].action === "read" && root.conversation.canRead === false) next += delta;
                        if (next >= 0 && next < list.count) {
                            list.currentIndex = next; list.positionViewAtIndex(next, ListView.Contain); list.forceLayout();
                            if (list.currentItem) list.currentItem.forceActiveFocus(Qt.TabFocusReason);
                        }
                    } else return;
                    event.accepted = true;
                }
            }
        }
    }
}
