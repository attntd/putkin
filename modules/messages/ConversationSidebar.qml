pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import "../../core"
import "../../core/ConversationRoute.js" as Route
import "../../components" as UI

FocusScope {
    id: root
    required property var hub
    property bool narrow: false
    property Item upTarget: null
    readonly property var adapter: hub.activeAdapter
    readonly property bool compact: !narrow && adapter !== null && adapter.cardsCollapsed
    property bool archived: false
    property var currentRoute: null
    property bool searchPending: false
    property int searchReason: Qt.TabFocusReason
    readonly property alias listView: list
    readonly property var filtered: hub.conversations.filter(item => !!(item.archived || item.hidden) === archived
        && (item.title + " " + item.searchText + " " + item.serviceName).toLocaleLowerCase().includes(search.text.toLocaleLowerCase()))
    readonly property int archiveCount: hub.conversations.filter(item => item.archived || item.hidden).length
    implicitWidth: compact ? 64 : 280
    signal conversationRequested(var route, int reason)
    signal menuRequested(var route, Item trigger, int reason)
    signal newRequested(int reason)
    function remember(): void { currentRoute = filtered[list.currentIndex] ? Route.copy(filtered[list.currentIndex].route) : null; }
    function reconcile(): void {
        const index = filtered.findIndex(c => Route.equal(c.route, currentRoute));
        list.currentIndex = index >= 0 ? index : Math.max(0, Math.min(list.currentIndex, list.count - 1));
        if (index < 0) remember();
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function focusList(reason = Qt.TabFocusReason, selected = true): void {
        if (selected && adapter && adapter.selectedRoute) {
            const conversation = hub.conversations.find(c => Route.equal(c.route, adapter.selectedRoute));
            if (conversation) archived = !!(conversation.archived || conversation.hidden);
            currentRoute = Route.copy(adapter.selectedRoute);
        }
        reconcile();
        list.focusReason = reason; list.forceActiveFocus(reason);
    }
    function focusSearch(reason: int): void {
        searchReason = reason;
        if (compact) { searchPending = true; adapter.setCardsCollapsed(false); }
        else search.forceActiveFocus(reason);
    }
    onCompactChanged: if (!compact && searchPending) {
        searchPending = false; searchFocusTimer.restart();
    }
    onFilteredChanged: reconcileTimer.restart()
    Timer { id: reconcileTimer; interval: 0; onTriggered: root.reconcile() }
    Timer { id: searchFocusTimer; interval: 0; onTriggered: search.forceActiveFocus(root.searchReason) }
    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.space8
        GridLayout {
            Layout.fillWidth: true
            columns: root.compact ? 1 : 3
            columnSpacing: Metrics.space4
            rowSpacing: Metrics.space8
            UI.NavigationButton {
                id: toggle
                objectName: "toggleConversationCards"
                text: root.compact ? qsTr("Pokaż karty") : qsTr("Ukryj karty")
                tooltip: ""
                visible: !root.narrow
                enabled: root.adapter !== null && !root.adapter.layoutBusy
                Layout.fillWidth: root.compact
                Layout.preferredWidth: Metrics.controlHeight
                rightTarget: newButton
                downTarget: root.compact ? newButton : search
                contentItem: UI.Glyph { symbol: "menu"; color: toggle.foreground }
                onClicked: root.adapter.setCardsCollapsed(!root.compact)
            }
            Text {
                visible: !root.compact
                Layout.fillWidth: true
                text: root.archived ? qsTr("Archiwum") : qsTr("Wiadomości")
                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize; font.bold: true
            }
            UI.NavigationButton {
                id: newButton
                objectName: "newConversation"
                text: qsTr("Nowa rozmowa"); tooltip: ""
                enabled: root.adapter !== null && root.adapter.canCreate
                Layout.fillWidth: root.compact
                Layout.preferredWidth: Metrics.controlHeight
                leftTarget: toggle
                upTarget: root.compact ? toggle : root.upTarget
                downTarget: root.compact ? searchButton : search
                contentItem: UI.Glyph { symbol: "add"; color: newButton.foreground }
                onClicked: root.newRequested(focusReason)
            }
        }
        UI.NavigationButton {
            id: searchButton
            objectName: "showConversationSearch"
            visible: root.compact
            Layout.fillWidth: true
            text: qsTr("Szukaj rozmowy"); tooltip: ""
            upTarget: newButton; downTarget: list
            contentItem: UI.Glyph { symbol: "search"; color: searchButton.foreground }
            onClicked: root.focusSearch(focusReason)
        }
        UI.TextField {
            id: search
            objectName: "conversationSearch"
            visible: !root.compact
            Layout.fillWidth: true
            Accessible.name: qsTr("Szukaj rozmowy")
            onTextChanged: { root.currentRoute = null; list.currentIndex = 0; }
            Keys.onUpPressed: newButton.forceActiveFocus(Qt.TabFocusReason)
            Keys.onDownPressed: root.focusList(Qt.TabFocusReason, false)
            Keys.onEscapePressed: root.focusList(Qt.TabFocusReason, false)
            Keys.onReturnPressed: if (root.filtered[list.currentIndex]) root.conversationRequested(root.filtered[list.currentIndex].route, Qt.TabFocusReason)
        }
        ListView {
            id: list
            objectName: "conversationList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.filtered
            clip: true
            spacing: Metrics.space4
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            activeFocusOnTab: true
            property int focusReason: Qt.OtherFocusReason
            Keys.forwardTo: [listInput]
            UI.ControlInput { id: listInput; control: list }
            UI.KineticScroll { id: listScroll; flickable: list }
            Controls.ScrollBar.vertical: UI.ScrollBar {}
            Keys.onPressed: event => {
                listScroll.reset(); list.cancelFlick();
                const contextKey = event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && event.modifiers === Qt.ShiftModifier);
                if (contextKey && root.filtered[currentIndex]) {
                    root.menuRequested(root.filtered[currentIndex].route, list, Qt.TabFocusReason); event.accepted = true; return;
                }
                if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
                if ((event.key === Qt.Key_J || event.key === Qt.Key_Down) && currentIndex >= count - 1) archiveButton.forceActiveFocus(Qt.TabFocusReason);
                else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) currentIndex = Math.min(count - 1, currentIndex + 1);
                else if ((event.key === Qt.Key_K || event.key === Qt.Key_Up) && currentIndex <= 0) {
                    if (root.upTarget && root.upTarget.visible) root.upTarget.forceActiveFocus(Qt.TabFocusReason);
                    else root.focusSearch(Qt.TabFocusReason);
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) currentIndex = Math.max(0, currentIndex - 1);
                else if ([Qt.Key_H, Qt.Key_Left, Qt.Key_Slash].includes(event.key)) root.focusSearch(Qt.TabFocusReason);
                else if ([Qt.Key_L, Qt.Key_Right, Qt.Key_Return, Qt.Key_Enter].includes(event.key) && root.filtered[currentIndex]) {
                    if (!event.isAutoRepeat) root.conversationRequested(root.filtered[currentIndex].route, Qt.TabFocusReason);
                } else return;
                root.remember(); positionViewAtIndex(currentIndex, ListView.Contain); event.accepted = true;
            }
            delegate: UI.Button {
                id: entry
                required property var modelData
                required property int index
                width: list.width
                height: 64
                padding: Metrics.space8
                text: modelData.title
                tooltip: ""
                focusPolicy: Qt.NoFocus
                highlighted: Route.equal(root.adapter ? root.adapter.selectedRoute : null, modelData.route)
                onClicked: {
                    list.currentIndex = index; root.remember(); list.focusReason = Qt.MouseFocusReason;
                    root.conversationRequested(modelData.route, Qt.MouseFocusReason);
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: {
                        list.currentIndex = entry.index; root.remember(); root.focusList(Qt.MouseFocusReason, false);
                        root.menuRequested(entry.modelData.route, list, Qt.MouseFocusReason);
                    }
                }
                contentItem: RowLayout {
                    spacing: Metrics.space8
                    ConversationAvatar {
                        conversation: entry.modelData
                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignHCenter
                        Rectangle {
                            objectName: "conversationUnreadBadge"
                            visible: entry.modelData.unreadCount > 0 || !!entry.modelData.markedUnread
                            anchors.right: parent.right; anchors.bottom: parent.bottom
                            width: Math.max(12, countLabel.implicitWidth + 8); height: 16
                            color: Theme.text; border.color: Theme.backgroundStrong; border.width: 1
                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: entry.modelData.unreadCount ? Math.min(99, entry.modelData.unreadCount) + (entry.modelData.unreadCount > 99 ? "+" : "") : ""
                                color: Theme.backgroundStrong; font.family: Theme.fontFamily; font.pixelSize: 10
                            }
                        }
                    }
                    ColumnLayout {
                        visible: !root.compact
                        Layout.fillWidth: true
                        spacing: Metrics.space4
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight
                            font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize
                            font.bold: entry.modelData.unreadCount > 0 || !!entry.modelData.markedUnread
                            color: entry.foreground
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.previewText || entry.modelData.serviceName
                            textFormat: Text.PlainText; elide: Text.ElideRight; maximumLineCount: 1
                            font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
                            color: entry.foreground
                        }
                    }
                    UI.Glyph {
                        visible: !root.compact && (!!entry.modelData.pinned || !!entry.modelData.muted)
                        symbol: entry.modelData.pinned ? "push_pin" : "notifications_off"
                        color: entry.foreground
                    }
                }
                background: UI.AccentRectangle {
                    color: entry.fillColor; radius: Metrics.radius
                    border.width: Metrics.borderWidth
                    border.color: entry.down ? Theme.text : entry.highlighted ? Theme.accentBorder : Theme.border
                    accentFill: entry.accentFill; accentOutline: entry.accentFill && !entry.down
                    UI.FocusIndicator { control: list; shown: list.currentIndex === entry.index }
                }
                Component.onCompleted: { const owner = root.hub.adapterFor(modelData.route); if (owner) owner.ensureAvatar(modelData); }
            }
        }
        UI.NavigationButton {
            id: archiveButton
            objectName: "showConversationArchive"
            Layout.fillWidth: true
            text: root.archived ? qsTr("Wszystkie rozmowy") : qsTr("Archiwum") + (root.archiveCount ? " · " + root.archiveCount : "")
            tooltip: ""
            checked: root.archived
            upTarget: list
            onClicked: { root.archived = !root.archived; root.currentRoute = null; list.currentIndex = 0; root.focusList(focusReason, false); }
            contentItem: UI.IconLabel {
                text: root.compact ? "" : archiveButton.text
                leadingIcon: root.archived ? "chat" : "archive"
                color: archiveButton.foreground
                font: archiveButton.font
            }
        }
        Text {
            visible: !root.compact
            Layout.fillWidth: true
            text: root.adapter ? root.adapter.displayName + " · " + root.adapter.statusText : ""
            color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
            elide: Text.ElideRight
        }
    }
}
