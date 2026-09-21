pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../../core"
import "../../components" as UI

ColumnLayout {
    id: root
    required property var adapter
    property string mode: "contact"
    property var selectedMembers: []
    property string avatar: ""
    property string contactKey: ""
    readonly property var filtered: adapter ? (mode === "groups" ? adapter.directory.groups.map(g => ({id: g.groupId, title: g.name, subtitle: g.membership, group: true})) : adapter.contacts).filter(v => (v.title + " " + v.subtitle).toLocaleLowerCase().includes(recipient.text.toLocaleLowerCase())) : []
    signal dismissed()
    spacing: Metrics.space8
    function focusInitial(): void { recipient.forceActiveFocus(Qt.TabFocusReason); }
    function choose(contact: var): void {
        contactKey = contact.id;
        if (mode === "groups") adapter.openGroup(contact.id);
        else if (mode === "group") selectedMembers = selectedMembers.includes(contact.id) ? selectedMembers.filter(v => v !== contact.id) : selectedMembers.concat([contact.id]);
        else adapter.createConversation("", contact);
    }
    onFilteredChanged: Qt.callLater(restoreSelection)
    function restoreSelection(): void {
        const index = filtered.findIndex(c => c.id === contactKey);
        if (index >= 0) contacts.currentIndex = index;
    }
    Flow {
        Layout.fillWidth: true
        spacing: Metrics.space4
        UI.NavigationButton { text: qsTr("Wróć"); onClicked: root.dismissed() }
        UI.NavigationButton { text: qsTr("Kontakt"); checked: root.mode === "contact"; onClicked: root.mode = "contact" }
        UI.NavigationButton { objectName: "browseGroups"; visible: root.adapter && root.adapter.canManageGroups; text: qsTr("Grupy"); checked: root.mode === "groups"; onClicked: root.mode = "groups" }
        UI.NavigationButton { objectName: "newGroupMode"; visible: root.adapter && root.adapter.canManageGroups; text: qsTr("Utwórz grupę"); checked: root.mode === "group"; onClicked: root.mode = "group" }
        UI.NavigationButton { objectName: "joinGroupMode"; visible: root.adapter && root.adapter.canManageGroups; text: qsTr("Link"); checked: root.mode === "link"; onClicked: root.mode = "link" }
        UI.NavigationButton { objectName: "refreshContacts"; visible: root.adapter && root.adapter.canManageGroups; text: qsTr("Odśwież"); enabled: root.adapter && !root.adapter.directoryBusy; onClicked: root.adapter.refreshDirectory() }
    }
    UI.TextField {
        id: groupName
        objectName: "newGroupName"
        visible: root.mode === "group"
        Layout.fillWidth: true
        Accessible.name: qsTr("Nazwa grupy")
        placeholderText: Accessible.name
        maximumLength: 128
    }
    Flow {
        Layout.fillWidth: true
        visible: root.mode === "group"
        spacing: Metrics.space4
        UI.NavigationButton { objectName: "newGroupAvatar"; text: root.avatar ? qsTr("Zmień avatar") : qsTr("Avatar"); onClicked: avatarPicker.active = true }
        UI.NavigationButton { visible: root.avatar !== ""; text: qsTr("Usuń avatar"); onClicked: root.avatar = "" }
        UI.NavigationButton {
            objectName: "createGroup"
            text: qsTr("Utwórz") + " · " + root.selectedMembers.length
            enabled: root.adapter && !root.adapter.directoryBusy && !root.adapter.createUncertain && groupName.text.trim().length > 0 && root.selectedMembers.length > 0
            onClicked: root.adapter.createGroup(groupName.text, root.selectedMembers, root.avatar)
        }
    }
    UI.TextField {
        id: link
        objectName: "groupLink"
        Layout.fillWidth: true
        visible: root.mode === "link"
        placeholderText: qsTr("Link grupy")
        Accessible.name: placeholderText
        maximumLength: 2048
        onAccepted: { if (root.adapter && !root.adapter.directoryBusy) root.adapter.joinGroup(text); }
    }
    UI.NavigationButton {
        objectName: "joinGroup"
        visible: root.mode === "link"
        text: qsTr("Dołącz")
        enabled: link.text.length > 0 && root.adapter && !root.adapter.directoryBusy
        onClicked: root.adapter.joinGroup(link.text)
    }
    Repeater {
        model: root.adapter ? root.adapter.groupOperations.filter(o => ["unknown", "partial", "requesting"].includes(o.state)) : []
        delegate: ColumnLayout {
            id: operation
            required property var modelData
            Layout.fillWidth: true
            Text { text: operation.modelData.state === "requesting" ? qsTr("Oczekiwanie na akceptację") : operation.modelData.state === "partial" ? qsTr("Częściowy wynik") : qsTr("Wynik nieznany"); color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize }
            UI.NavigationButton { objectName: "reconcileGroup"; text: qsTr("Sprawdź grupy"); enabled: root.adapter && !root.adapter.directoryBusy; onClicked: root.adapter.reconcileGroup(operation.modelData.operationId, "") }
            UI.NavigationButton { visible: !!operation.modelData.target; text: qsTr("Użyj bieżącej grupy"); enabled: root.adapter && !root.adapter.directoryBusy; onClicked: root.adapter.reconcileGroup(operation.modelData.operationId, operation.modelData.target) }
            Repeater {
                model: operation.modelData.candidates
                delegate: UI.NavigationButton {
                    required property string modelData
                    Layout.fillWidth: true
                    text: qsTr("Użyj grupy") + " · " + ((root.adapter.directory.groups.find(g => g.groupId === modelData) || {}).name || modelData)
                    onClicked: root.adapter.reconcileGroup(operation.modelData.operationId, modelData)
                }
            }
        }
    }
    UI.TextField {
        id: recipient
        objectName: "newRecipient"
        visible: root.mode !== "link"
        Layout.fillWidth: true
        Accessible.name: root.mode === "groups" ? qsTr("Szukaj grupy") : qsTr("Numer lub nazwa użytkownika")
        placeholderText: Accessible.name
        enabled: root.adapter !== null && !root.adapter.resolving
        onAccepted: { if (root.adapter && root.mode === "contact") root.adapter.createConversation(text, null); }
        Keys.onDownPressed: contacts.forceActiveFocus(Qt.TabFocusReason)
    }
    UI.NavigationButton {
        objectName: "resolveRecipient"
        visible: root.mode === "contact"
        text: qsTr("Otwórz rozmowę")
        enabled: recipient.text.trim().length > 0 && root.adapter && root.adapter.canCreate && !root.adapter.resolving
        upTarget: recipient
        downTarget: contacts
        onClicked: root.adapter.createConversation(recipient.text, null)
    }
    RowLayout {
        visible: root.mode === "contact" && root.adapter && root.adapter.profileDetails !== null
        Layout.fillWidth: true
        Image { source: root.adapter && root.adapter.profileDetails ? root.adapter.profileDetails.avatar || "" : ""; visible: source.toString() !== ""; Layout.preferredWidth: 48; Layout.preferredHeight: 48; fillMode: Image.PreserveAspectFit }
        Text {
            Layout.fillWidth: true
            text: root.adapter && root.adapter.profileDetails ? [root.adapter.profileDetails.profileName, root.adapter.profileDetails.number, root.adapter.profileDetails.username, root.adapter.profileDetails.about].filter(Boolean).join("\n") : ""
            textFormat: Text.PlainText; wrapMode: Text.Wrap
            color: Theme.textMuted; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
        }
    }
    ListView {
        id: contacts
        objectName: "contactList"
        visible: root.mode !== "link"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: visible ? root.filtered : []
        keyNavigationEnabled: false
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        Keys.onPressed: event => {
            if (event.modifiers !== Qt.NoModifier) return;
            if (event.key === Qt.Key_J || event.key === Qt.Key_Down) currentIndex = Math.min(count - 1, currentIndex + 1);
            else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) currentIndex = Math.max(0, currentIndex - 1);
            else if (event.key === Qt.Key_H) recipient.forceActiveFocus(Qt.TabFocusReason);
            else if ((event.key === Qt.Key_L || event.key === Qt.Key_Return) && currentIndex >= 0 && currentIndex < count) root.choose(root.filtered[currentIndex]);
            else return;
            if (currentIndex >= 0 && currentIndex < count) root.contactKey = root.filtered[currentIndex].id;
            positionViewAtIndex(currentIndex, ListView.Contain); event.accepted = true;
        }
        delegate: RowLayout {
            id: contactRow
            required property var modelData
            required property int index
            width: contacts.width
            spacing: Metrics.space4
            UI.Button {
                id: contactButton
                Layout.fillWidth: true
                text: contactRow.modelData.title + (contactRow.modelData.subtitle === "invited" ? " · " + qsTr("Zaproszenie") : contactRow.modelData.subtitle === "requesting" ? " · " + qsTr("Oczekiwanie") : "")
                checked: root.mode === "group" && root.selectedMembers.includes(contactRow.modelData.id)
                enabled: root.adapter && root.adapter.canCreate && !root.adapter.resolving
                onClicked: { contacts.currentIndex = contactRow.index; root.choose(contactRow.modelData); }
                UI.FocusIndicator { control: contactButton; visible: contacts.activeFocus && contacts.currentIndex === contactRow.index }
            }
            UI.NavigationButton {
                objectName: "contactProfile"
                visible: root.adapter && root.adapter.canManageGroups && root.mode !== "groups"
                text: qsTr("Profil")
                enabled: root.adapter && !root.adapter.directoryBusy
                onClicked: { root.contactKey = contactRow.modelData.id; root.adapter.inspectContact(contactRow.modelData.id); }
            }
        }
    }
    Item { visible: root.mode === "link"; Layout.fillHeight: true }
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
}
