pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import "../../core"
import "../../core/ConversationRoute.js" as Route
import "../../components" as UI

FocusScope {
    id: root
    property bool detailsOpen: false
    property bool showHidden: false
    required property var hub
    readonly property bool accentScope: true
    readonly property var adapter: hub.activeAdapter
    readonly property alias historyView: history
    readonly property bool narrow: width < 680
    property bool detail: false
    property bool creating: false
    property bool readingEnabled: false
    property var previewAttachment: null
    property Item previewFocus: null
    property int previewReason: Qt.TabFocusReason
    property int conversationFocusReason: Qt.TabFocusReason
    property bool composerFocusPending: false
    readonly property var filtered: hub.conversations.filter(item => (showHidden || !item.hidden) && (item.title + " " + item.searchText + " " + item.serviceName).toLocaleLowerCase().indexOf(search.text.toLocaleLowerCase()) >= 0)
    signal dismissed()
    function focusInitial(compose = false): void {
        if (compose) {
            detail = true; creating = false;
            focusComposer();
        } else showList();
    }
    function focusComposer(reason = Qt.TabFocusReason): void {
        conversationFocusReason = reason;
        composerFocusPending = true;
        conversation.forceActiveFocus(reason);
        restoreComposerFocus();
    }
    function restoreComposerFocus(): void {
        if (!composerFocusPending || !composer.visible || !composer.editor.enabled) return;
        composerFocusPending = false;
        composer.editor.forceActiveFocus(conversationFocusReason);
    }
    function openConversation(route: var, reason: int): void {
        conversationFocusReason = reason;
        root.hub.openConversation(route);
    }
    function showList(reason = Qt.TabFocusReason): void {
        composerFocusPending = false;
        creating = false; detail = false;
        const selected = filtered.findIndex(item => Route.equal(item.route, adapter ? adapter.selectedRoute : null));
        if (selected >= 0) list.currentIndex = selected;
        else if (list.currentIndex < 0 && list.count) list.currentIndex = 0;
        list.forceActiveFocus(reason);
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundStrong
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: Metrics.space12
        spacing: Metrics.space12
        ColumnLayout {
            id: sidebar
            visible: !root.narrow || (!root.detail && !root.creating)
            Layout.preferredWidth: root.narrow ? root.width - 24 : 260
            Layout.fillWidth: root.narrow
            Layout.fillHeight: true
            spacing: Metrics.space8
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTr("Wiadomości")
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.fontSize
                    font.bold: true
                    color: Theme.text
                    Layout.fillWidth: true
                }
                UI.NavigationButton {
                    id: newButton
                    objectName: "newConversation"
                    text: qsTr("Nowa rozmowa")
                    Layout.preferredWidth: Metrics.controlHeight
                    enabled: root.adapter !== null && root.adapter.canCreate
                    downTarget: search
                    contentItem: UI.Glyph { symbol: "add"; color: newButton.foreground }
                    onClicked: { root.creating = true; root.detail = false; newView.focusInitial(); }
                }
            }
            UI.TextField {
                id: search
                objectName: "conversationSearch"
                Accessible.name: qsTr("Szukaj rozmowy")
                Layout.fillWidth: true
                onTextChanged: list.currentIndex = 0
                Keys.onDownPressed: list.forceActiveFocus(Qt.TabFocusReason)
                Keys.onEscapePressed: list.forceActiveFocus(Qt.TabFocusReason)
                Keys.onReturnPressed: { if (root.filtered.length) root.openConversation(root.filtered[list.currentIndex < 0 ? 0 : list.currentIndex].route, Qt.TabFocusReason); }
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
                    listScroll.reset();
                    list.cancelFlick();
                    if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
                    if (event.key === Qt.Key_J || event.key === Qt.Key_Down) currentIndex = Math.min(count - 1, currentIndex + 1);
                    else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) currentIndex = Math.max(0, currentIndex - 1);
                    else if (event.key === Qt.Key_H || event.key === Qt.Key_Slash) search.forceActiveFocus(Qt.TabFocusReason);
                    else if ((event.key === Qt.Key_L || event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && currentIndex >= 0 && currentIndex < count) {
                        if (!event.isAutoRepeat) root.openConversation(root.filtered[currentIndex].route, Qt.TabFocusReason);
                    }
                    else return;
                    positionViewAtIndex(currentIndex, ListView.Contain);
                    event.accepted = true;
                }
                delegate: UI.Button {
                    id: entry
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 68
                    text: modelData.title
                    focusPolicy: Qt.ClickFocus
                    highlighted: Route.equal(root.adapter ? root.adapter.selectedRoute : null, modelData.route)
                    onClicked: { list.currentIndex = index; root.openConversation(modelData.route, focusReason); }
                    contentItem: Column {
                        spacing: Metrics.space4
                        Text {
                            width: parent.width
                            text: entry.modelData.title
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            font.family: Theme.fontFamily
                            font.pixelSize: Metrics.fontSize
                            font.bold: entry.modelData.unreadCount > 0
                            color: entry.foreground
                        }
                        Text {
                            width: parent.width
                            text: entry.modelData.serviceName + (entry.modelData.unreadCount ? " · " + entry.modelData.unreadCount : "")
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Metrics.smallFontSize
                            color: entry.foreground
                        }
                    }
                    UI.FocusIndicator { control: list; shown: list.currentIndex === entry.index }
                }
            }
            UI.NavigationButton {
                text: root.showHidden ? qsTr("Wszystkie rozmowy") : qsTr("Pokaż ukryte")
                visible: root.hub.conversations.some(c => c.hidden)
                onClicked: root.showHidden = !root.showHidden
            }
            Text {
                Layout.fillWidth: true
                text: root.adapter ? root.adapter.displayName + " · " + root.adapter.statusText : ""
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.smallFontSize
                elide: Text.ElideRight
            }
        }
        Rectangle { visible: !root.narrow; Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.border }
        NewConversation {
            id: newView
            visible: root.creating
            Layout.fillWidth: true
            Layout.fillHeight: true
            adapter: root.adapter
            onDismissed: root.showList()
        }
        FocusScope {
            id: conversation
            onActiveFocusChanged: if (!activeFocus) root.composerFocusPending = false
            visible: !root.creating && (!root.narrow || root.detail)
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                spacing: Metrics.space8
                RowLayout {
                    Layout.fillWidth: true
                    UI.NavigationButton {
                        id: back
                        objectName: "backToConversations"
                        visible: root.narrow
                        text: qsTr("Wróć")
                        rightTarget: history
                        onClicked: root.showList(focusReason)
                    }
                    Text {
                        Layout.fillWidth: true
                        objectName: "conversationTitle"
                        text: root.adapter && root.adapter.selectedConversation ? root.adapter.selectedConversation.title : qsTr("Wiadomości")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    UI.NavigationButton {
                        objectName: "conversationDetails"
                        visible: root.adapter && root.adapter.selectedConversation !== null
                        text: qsTr("Szczegóły")
                        onClicked: { if (root.adapter.canManageGroups) root.adapter.inspectGroup(); root.detailsOpen = true; }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    visible: root.adapter && root.adapter.selectedConversation && root.adapter.selectedConversation.requestState !== "accepted" && root.adapter.selectedConversation.requestState !== "member"
                    spacing: Metrics.space4
                    UI.NavigationButton {
                        objectName: "acceptMessageRequest"
                        visible: root.adapter && root.adapter.selectedConversation && root.adapter.selectedConversation.requestState === "pending"
                        text: qsTr("Przyjmij rozmowę")
                        enabled: root.adapter && !root.adapter.directoryBusy
                        onClicked: root.adapter.acceptConversation()
                    }
                    Text {
                        visible: root.adapter && root.adapter.selectedConversation && ["blocked", "invited", "requesting", "left", "terminated", "unknown"].includes(root.adapter.selectedConversation.requestState)
                        text: root.adapter && root.adapter.selectedConversation ? ({blocked: qsTr("Zablokowano"), invited: qsTr("Zaproszenie"), requesting: qsTr("Oczekiwanie na akceptację"), left: qsTr("Poza grupą"), terminated: qsTr("Grupa zakończona"), unknown: qsTr("Stan nieznany")})[root.adapter.selectedConversation.requestState] || "" : ""
                        color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
                    }
                }
                MessageHistory {
                    id: history
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    adapter: root.adapter
                    readingEnabled: root.readingEnabled && root.adapter && root.adapter.selectedConversation && root.adapter.selectedConversation.canRead !== false && !root.creating && !root.detailsOpen && !root.previewAttachment && (!root.narrow || root.detail)
                    onPreviewRequested: (attachment, reason) => {
                        root.previewFocus = root.Window.window ? root.Window.window.activeFocusItem : null;
                        root.previewReason = reason; root.previewAttachment = attachment;
                    }
                    onBackRequested: root.showList()
                    onComposeRequested: root.focusComposer()
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.adapter && root.adapter.typingAuthors.length > 0
                    text: root.adapter ? root.adapter.typingAuthors.join(", ") + qsTr(" pisze…") : ""
                    textFormat: Text.PlainText
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.smallFontSize
                    elide: Text.ElideRight
                }
                MessageComposer {
                    id: composer
                    editingEnabled: history.readingEnabled && root.adapter && root.adapter.canSend
                    enabled: root.adapter && root.adapter.canSend
                    visible: root.adapter !== null && root.adapter.selectedRoute !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(implicitHeight, Math.max(Metrics.controlHeight, root.height * .3))
                    adapter: root.adapter
                }
            }
        }
    }
    Connections {
        target: root.hub
        function onConversationOpened(_route: var): void {
            root.detail = true; root.creating = false;
            root.focusComposer(root.conversationFocusReason);
        }
    }
    Connections {
        target: composer.editor
        function onEnabledChanged(): void { Qt.callLater(root.restoreComposerFocus); }
    }
    Loader {
        anchors.fill: parent
        active: root.detailsOpen && root.adapter && root.adapter.selectedConversation !== null
        sourceComponent: ConversationDetails { adapter: root.adapter; onDismissed: { root.detailsOpen = false; root.focusComposer(); } }
    }
    Loader {
        id: mediaPreview
        anchors.fill: parent
        active: root.previewAttachment !== null
        sourceComponent: MediaPreview {
            attachment: root.previewAttachment
            adapter: root.adapter
            initialFocusReason: root.previewReason
            onDismissed: reason => {
                root.previewAttachment = null;
                if (root.previewFocus) root.previewFocus.forceActiveFocus(reason);
                else composer.editor.forceActiveFocus(reason);
            }
        }
    }
    Connections {
        target: root.adapter
        function onDraftReadyChanged(): void { Qt.callLater(root.restoreComposerFocus); }
        function onSelectedRouteChanged(): void { root.previewAttachment = null; root.detailsOpen = false; }
        function onHistoryChanged(_reset: bool): void {
            if (!root.previewAttachment || !root.adapter) return;
            const aid = root.previewAttachment.attachment_id;
            for (let i = 0; i < root.adapter.messages.count; i++) {
                if (JSON.parse(root.adapter.messages.get(i).attachmentsJson).some(a => a.attachment_id === aid)) return;
            }
            root.previewAttachment = null;
        }
    }
    Keys.priority: Keys.AfterItem
    Keys.onEscapePressed: { if (detailsOpen) detailsOpen = false; else if (creating || conversation.activeFocus || composerFocusPending) showList(); else dismissed(); }
    Component.onCompleted: { detail = adapter !== null && adapter.selectedRoute !== null; }
}
