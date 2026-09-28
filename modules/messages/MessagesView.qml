pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../core/ConversationRoute.js" as Route
import "../../components" as UI

FocusScope {
    id: root
    property bool detailsOpen: false
    property alias showHidden: sidebar.archived
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
    property bool settingComposerFocus: false
    property bool conversationInsert: true
    readonly property alias insertMode: composer.insertMode
    readonly property var filtered: sidebar.filtered
    readonly property alias list: sidebar.listView
    property var pendingDetailsRoute: null
    property int detailsReason: Qt.TabFocusReason
    property int managementReason: Qt.OtherFocusReason
    signal dismissed()
    function focusInitial(compose = false): void {
        if (compose) {
            conversationInsert = true;
            detail = true; creating = false;
            focusComposer();
        } else showList();
    }
    function focusComposer(reason = Qt.TabFocusReason, insert = true): void {
        conversationFocusReason = reason;
        composer.insertMode = insert;
        composerFocusPending = true;
        settingComposerFocus = true;
        conversation.forceActiveFocus(reason);
        settingComposerFocus = false;
        restoreComposerFocus();
    }
    function restoreComposerFocus(): void {
        if (!composerFocusPending || !composer.visible || !composer.editor.enabled) return;
        composerFocusPending = false;
        composer.editor.forceActiveFocus(conversationFocusReason);
    }
    function openConversation(route: var, reason: int): void {
        conversationFocusReason = reason;
        conversationInsert = reason === Qt.MouseFocusReason;
        root.hub.openConversation(route);
    }
    function showList(reason = Qt.TabFocusReason): void {
        composerFocusPending = false;
        composer.leaveInsert();
        creating = false; detail = false;
        sidebar.focusList(reason);
    }
    function openDetails(reason: int): void {
        detailsReason = reason;
        if (root.adapter.canManageGroups) {
            if (root.adapter.selectedConversation.kind === "group") root.adapter.inspectGroup();
            else if (root.adapter.selectedConversation.kind === "direct") root.adapter.inspectContact(root.adapter.selectedConversation.target);
        }
        root.detailsOpen = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundStrong
    }
    CallBar {
        id: callBar
        objectName: "callBar"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Metrics.space12
        calls: root.adapter ? root.adapter.calls : null
        downTarget: root.narrow && root.detail ? (callButton.enabled ? callButton : detailsButton) : root.list
    }
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: callBar.visible ? callBar.bottom : parent.top
        anchors.margins: Metrics.space12
        spacing: Metrics.space12
        ConversationSidebar {
            id: sidebar
            visible: !root.narrow || (!root.detail && !root.creating)
            Layout.preferredWidth: root.narrow ? root.width - 24 : implicitWidth
            Layout.fillWidth: root.narrow
            Layout.fillHeight: true
            hub: root.hub
            narrow: root.narrow
            upTarget: callBar.visible ? callBar.firstAction : null
            onConversationRequested: (route, reason) => root.openConversation(route, reason)
            onMenuRequested: (route, trigger, reason) => conversationMenu.show(route, trigger, reason)
            onNewRequested: reason => { root.creating = true; root.detail = false; newView.focusInitial(); }
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
                        rightTarget: detailsButton
                        downTarget: history
                        onClicked: root.showList(focusReason)
                    }
                    UI.NavigationButton {
                        id: detailsButton
                        objectName: "conversationDetails"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 48
                        Layout.preferredHeight: 48
                        padding: Metrics.space4
                        visible: root.adapter && root.adapter.selectedConversation !== null
                        text: qsTr("Szczegóły rozmowy"); tooltip: ""
                        leftTarget: back.visible ? back : root.list
                        rightTarget: callButton.visible && callButton.enabled ? callButton : menuButton
                        upTarget: callBar.visible ? callBar.firstAction : null
                        downTarget: history
                        onClicked: root.openDetails(focusReason)
                        background: Rectangle {
                            color: detailsButton.down ? Theme.border : "transparent"
                            UI.FocusIndicator { control: detailsButton }
                        }
                        contentItem: RowLayout {
                            spacing: Metrics.space8
                            ConversationAvatar {
                                conversation: root.adapter ? root.adapter.selectedConversation : null
                                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                            }
                            Text {
                                Layout.fillWidth: true
                                objectName: "conversationTitle"
                                text: root.adapter && root.adapter.selectedConversation ? root.adapter.selectedConversation.title : ""
                                color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize; font.bold: true
                                elide: Text.ElideRight; textFormat: Text.PlainText
                            }
                        }
                    }
                    UI.NavigationButton {
                        id: callButton
                        objectName: "startCall"
                        visible: root.adapter && root.adapter.selectedConversation !== null && root.adapter.selectedConversation.kind === "direct"
                        enabled: root.adapter && root.adapter.canCall
                        text: qsTr("Zadzwoń"); tooltip: ""
                        Layout.preferredWidth: Metrics.controlHeight
                        contentItem: UI.Glyph { symbol: "call"; color: callButton.foreground }
                        leftTarget: detailsButton
                        rightTarget: menuButton
                        upTarget: callBar.visible ? callBar.firstAction : null
                        downTarget: history
                        onClicked: root.adapter.calls.start(root.adapter.selectedConversation.conversationId)
                    }
                    UI.NavigationButton {
                        id: menuButton
                        objectName: "conversationOptions"
                        visible: root.adapter && root.adapter.selectedConversation !== null
                        text: qsTr("Zarządzaj rozmową"); tooltip: ""
                        Layout.preferredWidth: Metrics.controlHeight
                        contentItem: UI.Glyph { symbol: "more_horiz"; color: menuButton.foreground }
                        leftTarget: callButton.visible && callButton.enabled ? callButton : detailsButton
                        upTarget: callBar.visible ? callBar.firstAction : null
                        downTarget: history
                        onClicked: conversationMenu.show(root.adapter.selectedRoute, menuButton, focusReason)
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
                PinnedMessages {
                    Layout.fillWidth: true
                    adapter: root.adapter
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.adapter && !root.adapter.selectedRoute && root.adapter.lastError.length > 0
                    text: root.adapter ? root.adapter.lastError : ""
                    wrapMode: Text.Wrap
                    color: Theme.error; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
                    textFormat: Text.PlainText
                }
                MessageSelection {
                    Layout.fillWidth: true
                    visible: history.selecting
                    history: history
                }
                MessageHistory {
                    id: history
                    visible: root.adapter !== null && root.adapter.selectedRoute !== null
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    adapter: root.adapter
                    upTarget: callButton.visible && callButton.enabled ? callButton : detailsButton
                    readingEnabled: root.readingEnabled && root.adapter && root.adapter.selectedConversation && root.adapter.selectedConversation.canRead !== false && !root.creating && !root.detailsOpen && !root.previewAttachment && (!root.narrow || root.detail)
                    onPreviewRequested: (attachment, reason) => {
                        root.previewFocus = root.Window.window ? root.Window.window.activeFocusItem : null;
                        root.previewReason = reason; root.previewAttachment = attachment;
                    }
                    onBackRequested: root.showList()
                    onComposeRequested: insert => root.focusComposer(Qt.TabFocusReason, insert)
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
                    historyTarget: history
                    onHistoryRequested: history.focusEdge(false)
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
            if (Route.equal(root.pendingDetailsRoute, _route)) {
                root.pendingDetailsRoute = null; root.openDetails(root.detailsReason);
            } else root.focusComposer(root.conversationFocusReason, root.conversationInsert);
            root.conversationInsert = true;
        }
    }
    Connections {
        target: composer.editor
        function onEnabledChanged(): void { Qt.callLater(root.restoreComposerFocus); }
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged(): void {
            if (!root.composerFocusPending || root.settingComposerFocus) return;
            const item = root.Window.window.activeFocusItem;
            if (item && item !== conversation && item !== composer.editor) root.composerFocusPending = false;
        }
    }
    Loader {
        anchors.fill: parent
        active: root.detailsOpen && root.adapter && root.adapter.selectedConversation !== null
        sourceComponent: ConversationDetails {
            adapter: root.adapter
            initialFocusReason: root.detailsReason
            onManagementRequested: reason => root.managementReason = reason
            onDismissed: { root.detailsOpen = false; detailsButton.forceActiveFocus(root.detailsReason); }
        }
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
    ConversationMenu {
        id: conversationMenu
        hub: root.hub
        onActionRequested: reason => root.managementReason = reason
        onDetailsRequested: (route, reason) => {
            root.detailsReason = reason;
            if (Route.equal(route, root.adapter.selectedRoute)) root.openDetails(reason);
            else { root.pendingDetailsRoute = Route.copy(route); root.openConversation(route, reason); }
        }
    }
    Connections {
        target: root.adapter
        function onConversationManaged(cid: string, action: string, value: bool): void {
            if (value && ["archived", "markedUnread"].includes(action) && root.adapter.selectedRoute && root.adapter.selectedRoute.conversationId === cid) {
                root.adapter.closeConversation(); root.showList(root.managementReason);
            }
        }
        function onDraftReadyChanged(): void { Qt.callLater(root.restoreComposerFocus); }
        function onSelectedRouteChanged(): void { root.previewAttachment = null; root.detailsOpen = false; conversationMenu.dismiss(); }
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
    Keys.onPressed: event => {
        if (event.key === Qt.Key_I && event.modifiers === Qt.NoModifier && conversation.activeFocus
                && !root.detailsOpen && !root.previewAttachment && !root.creating) {
            if (!event.isAutoRepeat) root.focusComposer();
            event.accepted = true;
        }
    }
    Keys.onEscapePressed: { if (detailsOpen) detailsOpen = false; else if (creating || conversation.activeFocus || composerFocusPending) showList(); else dismissed(); }
    Component.onCompleted: { detail = adapter !== null && adapter.selectedRoute !== null; }
}
