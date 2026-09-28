pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Item {
    id: root
    required property var adapter
    required property var history
    property string messageId: ""
    property var message: null
    property var ids: []
    property string mode: "menu"
    property var destination: null
    property int pinDuration: 604800
    property string heading: ""
    property string reactionEmoji: ""
    readonly property bool opened: popup.visible
    readonly property var choices: options()
    property alias surface: popup
    function showReactionPeople(mid: string, trigger: Item, reason: int, emoji: string): void {
        reactionEmoji = emoji;
        show(mid, trigger, reason, "reactionPeople");
    }
    function show(mid: string, trigger: Item, reason: int, page: string, selected = []): void {
        messageId = mid; ids = selected.length ? selected.slice() : [mid];
        message = adapter ? adapter.rowById(mid) : null;
        if (!message || !history.readingEnabled) return;
        destination = null; mode = page; heading = "";
        popup.trigger = trigger; popup.reason = reason; popup.returnFocus = true;
        reactionLoader.active = false; reactionLoader.active = page === "reactions";
        popup.open();
        Qt.callLater(focusFirst);
    }
    function focusFirst(): void {
        if (!popup.visible) return;
        if (reactionLoader.item) (reactionLoader.item as ReactionChooser).focusFirst();
        else if (mode === "info" || mode === "reactionPeople") info.forceActiveFocus(popup.reason);
        else {
            list.currentIndex = 0; list.forceLayout();
            while (list.currentIndex < list.count - 1 && !choices[list.currentIndex].enabled) list.currentIndex++;
            if (list.currentItem) list.currentItem.forceActiveFocus(popup.reason);
        }
    }
    function dismiss(restore = true): void {
        if (!popup.visible || popup.closing) return;
        popup.returnFocus = restore; popup.closing = true; popup.close();
    }
    function validate(): void {
        if (!opened) return;
        if (!adapter || !history.readingEnabled || ids.some(id => !adapter.rowById(id))) { dismiss(false); return; }
        message = adapter.rowById(messageId);
        if (mode === "reactionPeople" && !reactionPeople().length) { dismiss(); return; }
        if (!message.canDeleteLocal && !message.canReact && !message.canReply && !message.canEdit) dismiss(false);
    }
    function option(id: string, label: string, enabled = true): var { return {id: id, label: label, enabled: enabled}; }
    function options(): var {
        if (!message) return [];
        if (mode === "menu") return [
            option("forwardMessage", qsTr("Przekaż"), message.canForward),
            ...(message.canEdit ? [option("editMessage", qsTr("Edytuj"))] : []),
            option("selectMessage", qsTr("Zaznacz")),
            option("copyMessage", qsTr("Skopiuj tekst"), message.canCopy),
            ...(message.canPin ? [option("pinMessage", message.pinned ? qsTr("Odepnij") : qsTr("Przypnij"))] : []),
            option("messageInfo", qsTr("Informacje")),
            option("deleteMessage", qsTr("Usuń"), message.canDeleteLocal)
        ];
        if (mode === "delete") return [option("deleteMessageLocal", qsTr("Usuń u mnie")),
            ...(ids.every(id => adapter.rowById(id) && adapter.rowById(id).canDeleteRemote)
                ? [option("deleteMessageEveryone", qsTr("Usuń u wszystkich"))] : [])];
        if (mode === "pin") return [option("pin24h", qsTr("24 godziny")), option("pin7d", qsTr("7 dni")),
            option("pin30d", qsTr("30 dni")), option("pinForever", qsTr("Na zawsze"))];
        if (mode === "replacePin") return [option("confirmPin", qsTr("Zastąp najstarszą przypiętą wiadomość")), option("cancelAction", qsTr("Anuluj"))];
        if (mode === "forward") return adapter.conversations.filter(c => c.canSend).map(c => ({
            id: "forwardDestination", label: c.title, enabled: true, conversationId: c.route.conversationId}));
        if (mode === "forwardConfirm") return [option("confirmForward", qsTr("Przekaż"), !adapter.forwardBusy), option("cancelAction", qsTr("Anuluj"))];
        return [];
    }
    function page(next: string, title = ""): void { mode = next; heading = title; Qt.callLater(focusFirst); }
    function activate(value: var, reason: int): void {
        popup.reason = reason;
        validate(); if (!popup.visible || !value.enabled) return;
        const id = value.id;
        if (id === "forwardMessage") page("forward", qsTr("Przekaż"));
        else if (id === "forwardDestination") { destination = value; page("forwardConfirm", value.label); }
        else if (id === "confirmForward") {
            if (adapter.forwardMessages(ids, destination.conversationId)) { history.clearSelection(); dismiss(); }
        } else if (id === "editMessage") { dismiss(false); adapter.beginEdit(messageId); }
        else if (id === "selectMessage") { history.toggleSelection(messageId); dismiss(false); history.forceActiveFocus(reason); }
        else if (id === "copyMessage") { clipboard.text = message.text; clipboard.selectAll(); clipboard.copy(); clipboard.deselect(); clipboard.text = ""; dismiss(); }
        else if (id === "pinMessage") {
            if (message.pinned) { adapter.pinMessage(messageId, -1, true); dismiss(); }
            else page("pin", qsTr("Przypnij"));
        } else if (["pin24h", "pin7d", "pin30d", "pinForever"].includes(id)) {
            pinDuration = {pin24h: 86400, pin7d: 604800, pin30d: 2592000, pinForever: -1}[id];
            if ((adapter.selectedConversation.pinnedMessages || []).length >= 3) page("replacePin");
            else { adapter.pinMessage(messageId, pinDuration, false); dismiss(); }
        } else if (id === "confirmPin") { adapter.pinMessage(messageId, pinDuration, false); dismiss(); }
        else if (id === "messageInfo") page("info", qsTr("Informacje"));
        else if (id === "deleteMessage") page("delete", qsTr("Usuń"));
        else if (id === "deleteMessageLocal" || id === "deleteMessageEveryone") {
            const selected = ids.slice(); dismiss(false); history.clearSelection();
            selected.forEach(mid => adapter.deleteMessage(mid, id === "deleteMessageLocal" ? "local" : "everyone"));
            history.forceActiveFocus(reason);
        } else if (id === "cancelAction") dismiss();
    }
    function information(): var {
        if (!message) return [];
        const lines = [message.author, message.day + " · " + message.time];
        if (message.status) lines.push(message.status);
        for (const r of JSON.parse(message.receiptsJson)) lines.push(adapter.personName(r.serviceId) + " · " +
            (r.viewedTimestampMs ? qsTr("Wyświetlono") : r.readTimestampMs ? qsTr("Przeczytano") : r.deliveryTimestampMs ? qsTr("Dostarczono") : qsTr("Brak raportu")));
        for (const r of JSON.parse(message.reactionsJson)) lines.push(r.emoji + " · " + r.people.map(p => p.name).join(", "));
        for (const v of JSON.parse(message.versionsJson)) lines.push(Qt.formatTime(new Date(v.timestampMs), "HH:mm") + " · " +
            ({read: qsTr("Przeczytano"), delivered: qsTr("Dostarczono"), received: qsTr("Odebrano"), sent: qsTr("Wysłano")}[v.status] || qsTr("Wysłano")));
        return lines;
    }
    function reactionPeople(): var {
        if (!message) return [];
        const reaction = JSON.parse(message.reactionsJson).find(r => r.emoji === reactionEmoji);
        return reaction ? reaction.people.map(person => person.name) : [];
    }
    TextEdit { id: clipboard; visible: false; textFormat: TextEdit.PlainText }
    MessagePopup {
        id: popup
        objectName: "messageActionPopup"
        preferredWidth: root.mode === "reactions" ? 306 : 280
        preferAbove: root.mode === "reactions" || root.mode === "reactionPeople"
        contentItem: Column {
            id: contents
            readonly property bool accentScope: true
            spacing: Metrics.space8
            Keys.onPressed: event => {
                popup.reason = Qt.TabFocusReason;
                if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true; }
            }
            Text {
                visible: root.heading !== ""
                width: parent.width
                text: root.heading; textFormat: Text.PlainText; wrapMode: Text.Wrap
                font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize; font.bold: true; color: Theme.text
            }
            Loader {
                id: reactionLoader
                width: parent.width
                visible: active
                active: false
                sourceComponent: ReactionChooser {
                    ownEmoji: root.message ? (JSON.parse(root.message.reactionsJson).find(r => r.mine) || {}).emoji || "" : ""
                    reason: popup.reason
                    availableHeight: (popup.parent ? popup.parent.height : 400) - 32
                    onChosen: (emoji, reason) => { popup.reason = reason; root.adapter.react(root.messageId, emoji, ownEmoji === emoji); root.dismiss(); }
                }
            }
            ListView {
                id: list
                objectName: "messageActionList"
                width: parent.width
                visible: root.mode !== "reactions" && root.mode !== "info" && root.mode !== "reactionPeople"
                height: visible ? Math.min(count * Metrics.controlHeight, (popup.parent ? popup.parent.height : 400) - 100) : 0
                model: root.choices
                clip: true
                keyNavigationEnabled: false
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: UI.ScrollBar {}
                delegate: UI.Button {
                    id: actionButton
                    required property var modelData
                    required property int index
                    objectName: modelData.id
                    width: list.width
                    text: modelData.label
                    tooltip: ""
                    enabled: modelData.enabled
                    background: Rectangle {
                        radius: Metrics.radius
                        color: actionButton.down ? Theme.border : actionButton.hovered ? Theme.surfaceHover : "transparent"
                        UI.FocusIndicator { control: actionButton }
                    }
                    contentItem: Text {
                        text: actionButton.text; font: actionButton.font; color: actionButton.foreground
                        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; textFormat: Text.PlainText
                    }
                    onClicked: root.activate(modelData, focusReason)
                    Keys.onPressed: event => {
                        if (event.modifiers !== Qt.NoModifier) return;
                        if (event.key === Qt.Key_H || event.key === Qt.Key_Left) root.dismiss();
                        else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_L, Qt.Key_Right].includes(event.key)) {
                            if (!event.isAutoRepeat) root.activate(modelData, Qt.TabFocusReason);
                        } else if ([Qt.Key_J, Qt.Key_Down, Qt.Key_K, Qt.Key_Up].includes(event.key)) {
                            const delta = event.key === Qt.Key_J || event.key === Qt.Key_Down ? 1 : -1;
                            let next = index + delta;
                            while (next >= 0 && next < list.count && !root.choices[next].enabled) next += delta;
                            if (next >= 0 && next < list.count) {
                                list.currentIndex = next; list.positionViewAtIndex(next, ListView.Contain); list.forceLayout();
                                if (list.currentItem) list.currentItem.forceActiveFocus(Qt.TabFocusReason);
                            }
                        } else return;
                        event.accepted = true;
                    }
                }
            }
            Flickable {
                id: info
                objectName: root.mode === "reactionPeople" ? "reactionPeople" : "messageInformation"
                width: parent.width
                height: visible ? Math.min(details.implicitHeight, (popup.parent ? popup.parent.height : 400) - 100) : 0
                visible: root.mode === "info" || root.mode === "reactionPeople"
                contentHeight: details.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: UI.ScrollBar {}
                UI.KineticScroll { flickable: info }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_J) contentY = Math.min(Math.max(0, contentHeight - height), contentY + 32);
                    else if (event.key === Qt.Key_K) contentY = Math.max(0, contentY - 32);
                    else if (event.key === Qt.Key_H) root.dismiss();
                    else return;
                    event.accepted = true;
                }
                Column {
                    id: details
                    width: info.width
                    spacing: Metrics.space8
                    Repeater {
                        model: root.mode === "reactionPeople" ? root.reactionPeople() : root.mode === "info" ? root.information() : []
                        delegate: Text {
                            required property string modelData
                            objectName: root.mode === "reactionPeople" ? "reactionPerson" : "messageInformationLine"
                            width: details.width; text: modelData; textFormat: Text.PlainText; wrapMode: Text.Wrap
                            color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize
                        }
                    }
                }
            }
        }
    }
    Connections {
        target: popup
        function onClosed(): void { root.messageId = ""; root.message = null; root.ids = []; reactionLoader.active = false; }
    }
}
