pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../../core"
import "../../components" as UI

FocusScope {
    id: root
    required property var adapter
    readonly property var conversation: adapter ? adapter.selectedConversation : null
    readonly property var group: conversation && conversation.kind === "group" ? adapter.groupDetails : null
    readonly property bool busy: !adapter || adapter.directoryBusy > 0
    property bool expirationOpen: false
    property var confirmation: null
    property string avatar: ""
    property string successor: ""
    signal dismissed()
    function ask(label: string, action: string, params: var): void {
        confirmation = {label: label, action: action, params: params};
        Qt.callLater(() => cancel.forceActiveFocus(Qt.TabFocusReason));
    }
    function confirm(): void {
        const value = confirmation; confirmation = null;
        if (value.action === "block") adapter.blockConversation(true, true);
        else adapter.groupAction(value.action, Object.assign({}, value.params, {confirm: group.groupId}));
    }
    function permissions(key: string, current: string): void {
        const params = {addMember: group.permissionAddMember === "ONLY_ADMINS" ? "only-admins" : "every-member",
            editDetails: group.permissionEditDetails === "ONLY_ADMINS" ? "only-admins" : "every-member",
            sendMessages: group.permissionSendMessage === "ONLY_ADMINS" ? "only-admins" : "every-member"};
        params[key] = current === "ONLY_ADMINS" ? "every-member" : "only-admins";
        adapter.groupAction("permissions", params);
    }
    function reveal(item: Item): void {
        const y = item.mapToItem(content, 0, 0).y;
        if (y < scroll.contentY) scroll.contentY = y;
        else if (y + item.height > scroll.contentY + scroll.height) scroll.contentY = y + item.height - scroll.height;
    }
    Rectangle { anchors.fill: parent; color: Theme.backgroundStrong }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: Metrics.space12; spacing: Metrics.space8
        RowLayout {
            Layout.fillWidth: true
            UI.NavigationButton { objectName: "closeConversationDetails"; text: qsTr("Wróć"); onClicked: root.dismissed() }
            Text { text: root.conversation ? root.conversation.title : ""; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize; elide: Text.ElideRight; Layout.fillWidth: true }
            UI.NavigationButton { objectName: "refreshGroup"; text: qsTr("Odśwież"); enabled: !root.busy; onClicked: { if (root.group) root.adapter.inspectGroup(); else root.adapter.inspectContact(root.conversation.target); } }
        }
        Flickable {
            id: scroll
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: width; contentHeight: content.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            ColumnLayout {
                id: content
                width: scroll.width
                spacing: Metrics.space8
                Image { source: root.group ? root.group.avatar || root.conversation.avatar || "" : root.conversation ? root.conversation.avatar || "" : ""; visible: source.toString() !== ""; Layout.preferredWidth: 64; Layout.preferredHeight: 64; fillMode: Image.PreserveAspectFit }
                Text {
                    Layout.fillWidth: true
                    text: root.group ? ({member: qsTr("Członek"), invited: qsTr("Zaproszenie"), requesting: qsTr("Oczekiwanie na akceptację"), left: qsTr("Poza grupą"), terminated: qsTr("Grupa zakończona")})[root.group.membership] || qsTr("Stan nieznany") : root.conversation ? root.conversation.target : ""
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
                }
                Flow {
                    Layout.fillWidth: true; spacing: Metrics.space4
                    UI.NavigationButton { objectName: "muteConversation"; text: root.conversation && root.conversation.muted ? qsTr("Włącz powiadomienia") : qsTr("Wycisz lokalnie"); onClicked: root.adapter.muteConversation(!root.conversation.muted); onEnsureVisible: item => root.reveal(item) }
                    UI.NavigationButton { objectName: "hideConversation"; text: root.conversation && root.conversation.hidden ? qsTr("Pokaż lokalnie") : qsTr("Ukryj lokalnie"); onClicked: root.adapter.hideConversation(!root.conversation.hidden); onEnsureVisible: item => root.reveal(item) }
                    UI.NavigationButton { objectName: "blockConversation"; visible: root.conversation && root.conversation.kind !== "note"; text: root.conversation && root.conversation.blocked ? qsTr("Odblokuj") : qsTr("Zablokuj"); enabled: !root.busy; onClicked: { if (root.conversation.blocked) root.adapter.blockConversation(false, false); else root.ask(qsTr("Zablokuj") + " · " + root.conversation.title, "block", {}); } onEnsureVisible: item => root.reveal(item) }
                    UI.NavigationButton { objectName: "acceptGroupInvitation"; visible: root.group && root.group.canAccept; text: qsTr("Przyjmij zaproszenie"); enabled: !root.busy; onClicked: root.adapter.groupAction("accept", {}); onEnsureVisible: item => root.reveal(item) }
                }
                UI.NavigationButton {
                    objectName: "conversationExpiration"
                    Layout.fillWidth: true
                    visible: root.conversation !== null
                    text: qsTr("Znikanie") + " · " + (root.adapter && root.adapter.selectedConversation && root.adapter.selectedConversation.expirationSeconds
                        ? root.adapter.selectedConversation.expirationSeconds + " s" : qsTr("Wyłączone"))
                    enabled: root.adapter && root.adapter.canSend && root.adapter.selectedConversation.canSetExpiration !== false
                    onClicked: root.expirationOpen = !root.expirationOpen
                    onEnsureVisible: item => root.reveal(item)
                }
                Flow {
                    Layout.fillWidth: true
                    visible: root.expirationOpen
                    spacing: Metrics.space4
                    Repeater {
                        model: [{seconds: 0, label: qsTr("Wyłączone")}, {seconds: 30, label: qsTr("30 s")},
                            {seconds: 300, label: qsTr("5 min")}, {seconds: 3600, label: qsTr("1 godz.")},
                            {seconds: 86400, label: qsTr("1 dzień")}, {seconds: 604800, label: qsTr("1 tydz.")}, {seconds: 2419200, label: qsTr("4 tyg.")}]
                        delegate: UI.NavigationButton {
                            required property var modelData
                            objectName: "expirationChoice" + modelData.seconds
                            text: modelData.label
                            onClicked: { root.adapter.setExpiration(modelData.seconds); root.expirationOpen = false; }
                            onEnsureVisible: item => root.reveal(item)
                        }
                    }
                }
                Repeater {
                    model: root.group ? root.adapter.groupOperations.filter(o => o.target === root.group.groupId && ["unknown", "partial", "requesting"].includes(o.state)) : []
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Text { text: parent.modelData.state === "unknown" ? qsTr("Wynik nieznany") : parent.modelData.state === "requesting" ? qsTr("Oczekiwanie na akceptację") : qsTr("Częściowy wynik"); color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize }
                        UI.NavigationButton { text: qsTr("Sprawdź stan"); enabled: !root.busy; onClicked: root.adapter.reconcileGroup(parent.modelData.operationId, ""); onEnsureVisible: item => root.reveal(item) }
                        UI.NavigationButton { text: qsTr("Przyjmij bieżący stan"); enabled: !root.busy; onClicked: root.adapter.reconcileGroup(parent.modelData.operationId, root.group.groupId); onEnsureVisible: item => root.reveal(item) }
                    }
                }
                UI.TextField { id: name; objectName: "groupName"; Layout.fillWidth: true; visible: !!root.group; enabled: root.group && root.group.canEdit && !root.busy; Accessible.name: qsTr("Nazwa grupy"); maximumLength: 128; onEnsureVisible: item => root.reveal(item) }
                UI.TextField { id: description; objectName: "groupDescription"; Layout.fillWidth: true; visible: !!root.group; enabled: root.group && root.group.canEdit && !root.busy; Accessible.name: qsTr("Opis grupy"); placeholderText: Accessible.name; maximumLength: 480; onEnsureVisible: item => root.reveal(item) }
                Flow {
                    Layout.fillWidth: true; visible: root.group && root.group.canEdit; spacing: Metrics.space4
                    UI.NavigationButton { text: root.avatar ? qsTr("Zmień avatar") : qsTr("Avatar"); enabled: !root.busy; onClicked: avatarPicker.active = true; onEnsureVisible: item => root.reveal(item) }
                    UI.NavigationButton { objectName: "saveGroupDetails"; text: qsTr("Zapisz"); enabled: !root.busy && name.text.trim().length > 0; onClicked: root.adapter.groupAction("details", {name: name.text, description: description.text, avatar: root.avatar}); onEnsureVisible: item => root.reveal(item) }
                }
                Repeater {
                    model: root.group ? root.group.members.concat(root.group.pendingMembers.map(m => Object.assign({}, m, {invited: true})), root.group.requestingMembers.map(m => Object.assign({}, m, {requesting: true}))) : []
                    delegate: ColumnLayout {
                        id: member
                        required property var modelData
                        Layout.fillWidth: true
                        readonly property string label: modelData.serviceId ? root.adapter.personName(modelData.serviceId) : modelData.number || qsTr("Nieznana osoba")
                        readonly property bool own: modelData.serviceId === root.group.ownServiceId
                        Text {
                            Layout.fillWidth: true
                            text: member.label + (member.modelData.isAdmin ? " · " + qsTr("Administrator") : member.modelData.invited ? " · " + qsTr("Zaproszono") : member.modelData.requesting ? " · " + qsTr("Prośba") : "")
                            textFormat: Text.PlainText; wrapMode: Text.Wrap
                            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize
                        }
                        Flow {
                            Layout.fillWidth: true; spacing: Metrics.space4
                            visible: root.group && root.group.canAdmin && !!member.modelData.serviceId && !member.own
                            UI.NavigationButton {
                                objectName: "memberRole"
                                visible: !member.modelData.invited && !member.modelData.requesting
                                text: member.modelData.isAdmin ? qsTr("Odbierz administratora") : qsTr("Nadaj administratora")
                                enabled: !root.busy
                                onClicked: { if (member.modelData.isAdmin) root.ask(text + " · " + member.label, "demote", {members: [member.modelData.serviceId]}); else root.adapter.groupAction("promote", {members: [member.modelData.serviceId]}); }
                                onEnsureVisible: item => root.reveal(item)
                            }
                            UI.NavigationButton { objectName: "approveMember"; visible: member.modelData.requesting === true; text: qsTr("Przyjmij"); enabled: !root.busy; onClicked: root.adapter.groupAction("approve", {members: [member.modelData.serviceId]}); onEnsureVisible: item => root.reveal(item) }
                            UI.NavigationButton { objectName: "removeMember"; text: member.modelData.requesting ? qsTr("Odrzuć") : qsTr("Usuń"); enabled: !root.busy; onClicked: root.ask(text + " · " + member.label, member.modelData.requesting ? "deny" : "remove", {members: [member.modelData.serviceId]}); onEnsureVisible: item => root.reveal(item) }
                            UI.NavigationButton { visible: !member.modelData.invited && !member.modelData.requesting; text: qsTr("Następca"); checked: root.successor === member.modelData.serviceId; onClicked: root.successor = member.modelData.serviceId; onEnsureVisible: item => root.reveal(item) }
                        }
                    }
                }
                UI.TextField { id: memberFilter; objectName: "addMemberFilter"; visible: root.group && root.group.canAdd; Layout.fillWidth: true; placeholderText: qsTr("Dodaj osobę"); Accessible.name: placeholderText; onEnsureVisible: item => root.reveal(item) }
                Repeater {
                    model: root.group && root.group.canAdd && memberFilter.text.length ? root.adapter.contacts.filter(c => (c.title + " " + c.subtitle).toLocaleLowerCase().includes(memberFilter.text.toLocaleLowerCase()) && !root.group.members.concat(root.group.pendingMembers).some(m => m.serviceId === c.id)).slice(0, 30) : []
                    delegate: UI.NavigationButton { required property var modelData; objectName: "addGroupMember"; Layout.fillWidth: true; text: qsTr("Dodaj") + " · " + modelData.title; enabled: !root.busy; onClicked: { root.adapter.groupAction("add", {members: [modelData.id]}); memberFilter.text = ""; } onEnsureVisible: item => root.reveal(item) }
                }
                Repeater {
                    model: root.group && root.group.canAdmin ? [{key: "addMember", label: qsTr("Dodawanie"), value: root.group.permissionAddMember}, {key: "editDetails", label: qsTr("Edycja"), value: root.group.permissionEditDetails}, {key: "sendMessages", label: qsTr("Wysyłanie"), value: root.group.permissionSendMessage}] : []
                    delegate: UI.NavigationButton { required property var modelData; Layout.fillWidth: true; text: modelData.label + " · " + (modelData.value === "ONLY_ADMINS" ? qsTr("Administratorzy") : qsTr("Wszyscy")); enabled: !root.busy; onClicked: root.permissions(modelData.key, modelData.value); onEnsureVisible: item => root.reveal(item) }
                }
                UI.TextField { visible: root.group && !!root.group.inviteLink; Layout.fillWidth: true; readOnly: true; text: root.group ? root.group.inviteLink : ""; Accessible.name: qsTr("Link zaproszenia"); onEnsureVisible: item => root.reveal(item) }
                Flow {
                    visible: root.group && root.group.canAdmin
                    Layout.fillWidth: true; spacing: Metrics.space4
                    UI.NavigationButton { text: qsTr("Włącz link"); enabled: !root.busy; onClicked: root.adapter.groupAction("link", {link: "enabled"}); onEnsureVisible: item => root.reveal(item) }
                    UI.NavigationButton { text: qsTr("Link z akceptacją"); enabled: !root.busy; onClicked: root.adapter.groupAction("link", {link: "enabled-with-approval"}); onEnsureVisible: item => root.reveal(item) }
                    UI.NavigationButton { text: qsTr("Wyłącz link"); enabled: !root.busy; onClicked: root.adapter.groupAction("link", {link: "disabled"}); onEnsureVisible: item => root.reveal(item) }
                    UI.NavigationButton { text: qsTr("Zmień link"); enabled: !root.busy; onClicked: root.ask(qsTr("Unieważnij link") + " · " + root.group.name, "link", {link: "enabled-with-approval", reset: true}); onEnsureVisible: item => root.reveal(item) }
                }
                UI.NavigationButton { objectName: "leaveGroup"; visible: root.group && root.group.canLeave; text: root.group && root.group.membership === "invited" ? qsTr("Odrzuć zaproszenie") : qsTr("Opuść grupę"); enabled: !root.busy; onClicked: root.ask(text + " · " + root.group.name, "quit", {admins: root.successor ? [root.successor] : []}); onEnsureVisible: item => root.reveal(item) }
            }
        }
        ColumnLayout {
            visible: root.confirmation !== null
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.confirmation ? root.confirmation.label : ""; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize }
            RowLayout {
                UI.NavigationButton { id: cancel; objectName: "cancelGroupAction"; text: qsTr("Anuluj"); rightTarget: confirm; onClicked: root.confirmation = null }
                UI.NavigationButton { id: confirm; objectName: "confirmGroupAction"; text: qsTr("Potwierdź"); enabled: !root.busy; leftTarget: cancel; onClicked: root.confirm() }
            }
        }
    }
    Connections {
        target: root.adapter
        function onGroupDetailsChanged(): void {
            if (!root.group) return;
            if (!name.activeFocus) name.text = root.group.name;
            if (!description.activeFocus) description.text = root.group.description;
            if (root.confirmation && !root.group.canAdmin && root.confirmation.action !== "quit" && root.confirmation.action !== "block") root.confirmation = null;
        }
    }
    Loader {
        id: avatarPicker
        active: false
        sourceComponent: FileDialog {
            title: qsTr("Avatar grupy")
            nameFilters: [qsTr("Obrazy (*.png *.jpg *.jpeg *.webp)")]
            onAccepted: { root.avatar = selectedFile.toString(); avatarPicker.active = false; }
            onRejected: avatarPicker.active = false
            Component.onCompleted: open()
        }
    }
    Keys.onEscapePressed: { if (confirmation) confirmation = null; else dismissed(); }
    Component.onCompleted: {
        if (group) { name.text = group.name; description.text = group.description; }
    }
}
