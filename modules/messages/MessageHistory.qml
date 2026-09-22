pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "MessageText.js" as MessageText
import "../../components" as UI

ListView {
    id: root
    FontMetrics { id: bodyMetrics; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize }
    FontMetrics { id: footerMetrics; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize }
    component BubbleButton: UI.NavigationButton {
        id: button
        width: Math.min(implicitWidth, parent.width)
        implicitHeight: Math.max(Metrics.controlHeight, implicitContentHeight + topPadding + bottomPadding)
        contentItem: Text {
            text: button.text
            font: button.font
            color: button.foreground
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
        }
    }
    component MessageButton: UI.NavigationButton {
        id: button
        padding: 0
        horizontalPadding: 0
        verticalPadding: 0
        implicitWidth: implicitContentWidth
        opacity: down ? .6 : hovered ? .8 : 1
        background: Item {
            UI.FocusIndicator {
                control: button
                border.color: button.foreground
                accentOutline: false
            }
        }
        contentItem: Text {
            text: button.text
            font: button.font
            color: button.foreground
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
        }
    }
    required property var adapter
    property string anchorId: ""
    property string actionsMessageId: ""
    property real anchorOffset: 0
    property bool followEnd: true
    property bool restoring: false
    property bool releasing: false
    property bool resetting: false
    Component.onCompleted: Qt.callLater(settleCallback)
    Component.onDestruction: { releasing = true; readBatch.stop(); }
    // Stable JS closures let callLater coalesce bursts while guarding teardown.
    property var restoreCallback: () => { if (Qt.isQtObject(root) && !root.releasing) root.restore(); }
    property var settleCallback: () => { if (Qt.isQtObject(root) && !root.releasing) root.settleEnd(); }
    property bool readingEnabled: false
    property int focusReason: Qt.OtherFocusReason
    objectName: "messageHistory"
    model: adapter && !resetting ? adapter.messages : null
    clip: true
    spacing: Metrics.space8
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 400
    keyNavigationEnabled: false
    Controls.ScrollBar.vertical: Controls.ScrollBar {}
    function revealControl(item: Item): void {
        const top = item.mapToItem(contentItem, 0, 0).y;
        if (top < contentY) { followEnd = false; contentY = top; }
        else if (top + item.height > contentY + height) { followEnd = false; contentY = top + item.height - height; }
    }
    function scheduleRead(): void {
        if (releasing) return;
        if (readingEnabled && visible && !restoring && !moving) readBatch.restart();
        else readBatch.stop();
    }
    function visibleUnread(): var {
        const ids = [];
        // Only instantiated delegates, never the whole history or cacheBuffer.
        for (const item of contentItem.children) {
            if (!item.messageId || !item.visible || !item.unread || !item.readable) continue;
            const box = item.bubble;
            // The whole bubble must be visible. An oversized message becomes
            // eligible only at its bottom, after its content can be read.
            const top = item.y + box.y, bottom = top + box.height;
            if (bottom <= contentY + height + .5 && bottom > contentY && (top >= contentY - .5 || box.height > height)) ids.push(item.messageId);
        }
        return ids;
    }
    Timer {
        id: readBatch
        interval: 250
        onTriggered: {
            if (!root.readingEnabled || !root.visible || root.restoring || root.moving || !root.adapter) return;
            const ids = root.visibleUnread();
            if (ids.length) root.adapter.markVisible(root.adapter.selectedRoute, ids);
        }
    }
    onReadingEnabledChanged: scheduleRead()
    onVisibleChanged: { scheduleEnd(); scheduleRead(); }
    onContentYChanged: scheduleRead()
    onHeightChanged: { scheduleEnd(); scheduleRead(); }
    onWidthChanged: { scheduleEnd(); scheduleRead(); }
    onRestoringChanged: scheduleRead()
    onMovingChanged: scheduleRead()
    function endVisible(): bool {
        const last = count ? itemAtIndex(count - 1) : null;
        return atYEnd || (last !== null && last.y + last.height <= contentY + height + 2);
    }
    function capture(reset: bool): void {
        if (restoring || releasing) return;
        followEnd = reset || endVisible() || count === 0;
        anchorId = "";
        for (let i = 0; i < count; i++) {
            const item = itemAtIndex(i);
            if (item && item.y + item.height > contentY) {
                anchorId = adapter.messages.get(i).messageId;
                anchorOffset = item.y - contentY;
                break;
            }
        }
        restoring = true;
    }
    function restore(): void {
        if (releasing) return;
        forceLayout();
        if (followEnd) { positionViewAtEnd(); Qt.callLater(settleCallback); }
        else if (anchorId) {
            for (let i = 0; i < count; i++) if (adapter.messages.get(i).messageId === anchorId) {
                positionViewAtIndex(i, ListView.Beginning);
                forceLayout();
                const item = itemAtIndex(i);
                if (item) contentY = item.y - anchorOffset;
                break;
            }
        }
        restoring = false;
    }
    function settleEnd(): void {
        if (followEnd && !moving && visible && width > 0 && height > 0) { forceLayout(); positionViewAtEnd(); }
    }
    function scheduleEnd(): void {
        if (!releasing && followEnd) Qt.callLater(settleCallback);
    }
    onMovementStarted: followEnd = false
    onMovementEnded: followEnd = atYEnd
    onContentHeightChanged: { scheduleEnd(); scheduleRead(); }
    Keys.onPressed: event => {
        root.focusReason = Qt.TabFocusReason;
        if (event.modifiers !== Qt.NoModifier) return;
        if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            followEnd = false;
            contentY = Math.max(originY, contentY - 48);
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            contentY = Math.min(originY + Math.max(0, contentHeight - height), contentY + 48);
            followEnd = atYEnd;
        }
        else if (event.key === Qt.Key_Escape && actionsMessageId) actionsMessageId = "";
        else if (event.key === Qt.Key_H) root.backRequested();
        else if (event.key === Qt.Key_L || event.key === Qt.Key_Return) root.composeRequested();
        else return;
        event.accepted = true;
    }
    signal backRequested()
    signal composeRequested()
    signal previewRequested(var attachment, int reason)
    header: UI.NavigationButton {
        objectName: "olderMessages"
        width: root.width
        height: visible ? implicitHeight + Metrics.space8 : 0
        visible: root.adapter !== null && root.adapter.nextCursor !== null
        enabled: root.adapter !== null && !root.adapter.loading
        text: qsTr("Starsze wiadomości")
        downTarget: root
        onClicked: root.adapter.loadMore()
    }
    delegate: Item {
        id: row
        required property int index
        required property bool system
        required property string receiptsJson
        required property string messageId
        required property string text
        required property string day
        required property string time
        required property string author
        required property bool outgoing
        required property string status
        required property string statusCode
        required property bool unread
        required property bool readable
        required property string attachmentsJson
        required property string operationId
        required property bool safeRetry
        required property bool canDeleteLocal
        required property bool canDeleteRemote
        required property int expirationSeconds
        required property bool canReact
        required property bool canEdit
        required property bool canReply
        required property bool edited
        required property string reactionsJson
        required property string quoteJson
        required property string mentionsJson
        required property string stylesJson
        required property string versionsJson
        required property string interactionJson
        readonly property var quote: JSON.parse(quoteJson)
        readonly property var interaction: JSON.parse(interactionJson)
        readonly property var reactions: JSON.parse(reactionsJson)
        readonly property var ownReaction: reactions.find(r => r.mine) || null
        readonly property bool accented: outgoing && !system
        readonly property color foreground: accented ? bubbleAccent.foreground : Theme.text
        readonly property color mutedForeground: accented ? bubbleAccent.foreground : Theme.textMuted
        UI.AccentCoordinates { id: bubbleAccent; item: column }
        readonly property alias bubble: column
        Accessible.role: Accessible.ListItem
        Accessible.name: author + ". " + text + ". " + time + (outgoing && status ? ". " + status : "")
        readonly property bool newDay: index <= 0 || !root.adapter.messages.get(index - 1) || root.adapter.messages.get(index - 1).day !== day
        width: root.width
        height: column.height + (newDay ? 36 : 0)
        Text {
            visible: row.newDay
            width: parent.width
            height: 28
            text: row.day
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.smallFontSize
            color: Theme.textMuted
        }
        UI.AccentRectangle {
            anchors.fill: column
            color: row.system ? "transparent" : row.accented ? Theme.accent : Theme.background
            border.color: row.accented ? Theme.accentBorder : Theme.border
            border.width: 1
            accentFill: row.accented
            accentOutline: row.accented
        }
        Column {
            id: column
            // Natural text widths stay independent of the wrapping width.
            readonly property real actionsWidth: actionsButton.visible ? actionsButton.width + Metrics.space8 : 0
            readonly property real textWidth: Math.max(messageBody.implicitWidth,
                authorLabel.visible ? authorLabel.implicitWidth : 0,
                quoteButton.visible ? quoteButton.implicitWidth : 0) + actionsWidth
            width: Math.min(root.width * .5, 2 * padding + Math.max(textWidth,
                footer.naturalWidth,
                operationButton.visible ? operationButton.implicitWidth : 0,
                interactionLabel.visible ? interactionLabel.implicitWidth : 0,
                interactionButton.visible ? interactionButton.implicitWidth : 0,
                attachments.count || root.actionsMessageId === row.messageId ? root.width * .5 : 0))
            x: row.system ? (root.width - width) / 2 : row.outgoing ? root.width - width : 0
            y: row.newDay ? 36 : 0
            padding: Metrics.space12
            spacing: Metrics.space4
            Item {
                width: column.width - 2 * Metrics.space12
                height: Math.max(messageContent.height, actionsButton.visible ? actionsButton.y + actionsButton.height : 0)
                Column {
                    id: messageContent
                    width: parent.width - (actionsButton.visible ? actionsButton.width + Metrics.space8 : 0)
                    spacing: Metrics.space4
                    Text {
                        id: authorLabel
                        width: parent.width
                        text: row.author
                        visible: !row.system && !row.outgoing && root.adapter.selectedConversation !== null && root.adapter.selectedConversation.kind === "group"
                        elide: Text.ElideRight
                        color: row.mutedForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.smallFontSize
                        textFormat: Text.PlainText
                    }
                    BubbleButton {
                        id: quoteButton
                        objectName: "messageQuote"
                        width: parent.width
                        visible: !!row.quote
                        text: row.quote ? (row.quote.available ? "↪ " : qsTr("Oryginał niedostępny · ")) + (row.quote.author || "") + ": " + row.quote.text : ""
                        enabled: !!row.quote && row.quote.available
                        onClicked: root.adapter.jumpTo(row.quote.messageId)
                    }
                    TextEdit {
                        id: messageBody
                        objectName: "messageBody"
                        width: parent.width
                        text: MessageText.render(row.text, JSON.parse(row.stylesJson), JSON.parse(row.mentionsJson))
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.RichText
                        color: row.foreground
                        selectionColor: Theme.backgroundStrong
                        selectedTextColor: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.fontSize
                        activeFocusOnPress: false
                    }
                }
                MessageButton {
                    id: actionsButton
                    objectName: "messageActions"
                    visible: row.canDeleteLocal || row.canReact || row.canReply || row.canEdit || !!row.interaction
                    anchors.right: parent.right
                    y: messageContent.y + messageBody.y
                    width: Metrics.iconSections.list.size
                    height: bodyMetrics.height
                    foreground: row.foreground
                    text: qsTr("Akcje wiadomości")
                    contentItem: UI.Glyph { symbol: "more_horiz"; color: actionsButton.foreground }
                    onClicked: root.actionsMessageId = root.actionsMessageId === row.messageId ? "" : row.messageId
                }
            }
            Repeater {
                id: attachments
                model: JSON.parse(row.attachmentsJson)
                delegate: AttachmentCard {
                    required property var modelData
                    width: column.width - 24
                    attachment: modelData
                    textColor: row.foreground
                    mutedTextColor: row.mutedForeground
                    onEnsureVisible: item => root.revealControl(item)
                    onPreviewRequested: (attachment, reason) => root.previewRequested(attachment, reason)
                }
            }
            BubbleButton {
                id: operationButton
                visible: row.operationId !== "" && (row.statusCode === "queued" || (row.statusCode === "failed" && row.safeRetry))
                text: row.statusCode === "queued" ? qsTr("Anuluj") : qsTr("Ponów")
                onClicked: root.adapter.changeOperation(row.operationId, row.statusCode !== "queued")
            }
            Loader {
                width: column.width - 24
                active: root.actionsMessageId === row.messageId
                visible: active
                sourceComponent: Column {
                spacing: Metrics.space4
                Flow {
                    width: parent.width
                    spacing: Metrics.space4
                    Repeater {
                        id: emojiChoices
                        model: ["👍", "❤️", "😂", "😮", "😢", "🙏", "🎉", "👎", "👩‍💻", "👍🏽"]
                        delegate: BubbleButton {
                            required property string modelData
                            required property int index
                            leftTarget: index > 0 ? emojiChoices.itemAt(index - 1) : actionsButton
                            rightTarget: index + 1 < emojiChoices.count ? emojiChoices.itemAt(index + 1) : replyAction
                            upTarget: actionsButton
                            downTarget: replyAction
                            onEnsureVisible: item => root.revealControl(item)
                            readonly property bool mine: row.reactions.some(r => r.emoji === modelData && r.mine)
                            text: modelData
                            checked: mine
                            enabled: row.canReact
                            Accessible.name: (mine ? qsTr("Usuń reakcję ") : qsTr("Reakcja ")) + modelData
                            onClicked: { root.adapter.react(row.messageId, modelData, mine); root.actionsMessageId = ""; }
                        }
                    }
                }
                Repeater {
                    model: JSON.parse(row.receiptsJson)
                    delegate: Text {
                        required property var modelData
                        width: column.width - 24
                        text: root.adapter.personName(modelData.serviceId) + " · " + (modelData.viewedTimestampMs ? qsTr("Wyświetlono") : modelData.readTimestampMs ? qsTr("Przeczytano") : modelData.deliveryTimestampMs ? qsTr("Dostarczono") : qsTr("Brak raportu"))
                        textFormat: Text.PlainText; wrapMode: Text.Wrap
                        color: row.mutedForeground; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
                    }
                }
                Repeater {
                    model: row.reactions
                    delegate: Text {
                        required property var modelData
                        width: column.width - 24
                        text: modelData.emoji + " · " + modelData.people.map(p => p.name).join(", ")
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: row.mutedForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.smallFontSize
                    }
                }
                Flow {
                    width: parent.width
                    spacing: Metrics.space4
                    BubbleButton {
                        id: replyAction
                        objectName: "replyMessage"
                        upTarget: emojiChoices.itemAt(0)
                        rightTarget: editAction.visible ? editAction : closeAction
                        onEnsureVisible: item => root.revealControl(item)
                        text: qsTr("Odpowiedz")
                        enabled: row.canReply
                        onClicked: { root.adapter.replyTo(row.messageId); root.actionsMessageId = ""; }
                    }
                    BubbleButton {
                        id: editAction
                        objectName: "editMessage"
                        leftTarget: replyAction
                        rightTarget: closeAction
                        upTarget: emojiChoices.itemAt(0)
                        onEnsureVisible: item => root.revealControl(item)
                        text: qsTr("Edytuj")
                        visible: row.canEdit
                        onClicked: { root.adapter.beginEdit(row.messageId); root.actionsMessageId = ""; }
                    }
                    BubbleButton {
                        id: deleteLocalAction
                        objectName: "deleteMessageLocal"
                        text: qsTr("Usuń u mnie")
                        visible: row.canDeleteLocal
                        leftTarget: editAction.visible ? editAction : replyAction
                        rightTarget: deleteRemoteAction.visible ? deleteRemoteAction : closeAction
                        onEnsureVisible: item => root.revealControl(item)
                        onClicked: { root.adapter.deleteMessage(row.messageId, "local"); root.actionsMessageId = ""; root.forceActiveFocus(focusReason); }
                    }
                    BubbleButton {
                        id: deleteRemoteAction
                        objectName: "deleteMessageEveryone"
                        text: qsTr("Usuń u wszystkich")
                        visible: row.canDeleteRemote
                        leftTarget: deleteLocalAction
                        rightTarget: closeAction
                        onEnsureVisible: item => root.revealControl(item)
                        onClicked: { root.adapter.deleteMessage(row.messageId, "everyone"); root.actionsMessageId = ""; root.forceActiveFocus(focusReason); }
                    }
                    BubbleButton {
                        id: closeAction
                        text: qsTr("Zamknij")
                        leftTarget: editAction.visible ? editAction : replyAction
                        upTarget: emojiChoices.itemAt(0)
                        onEnsureVisible: item => root.revealControl(item)
                        onClicked: { root.actionsMessageId = ""; root.forceActiveFocus(focusReason); }
                    }
                }
                BubbleButton {
                    objectName: "removeOwnReaction"
                    visible: !!row.ownReaction
                    text: qsTr("Usuń reakcję") + (row.ownReaction ? " " + row.ownReaction.emoji : "")
                    enabled: row.canReact
                    upTarget: replyAction
                    onEnsureVisible: item => root.revealControl(item)
                    onClicked: { root.adapter.react(row.messageId, row.ownReaction.emoji, true); root.actionsMessageId = ""; }
                }
                Repeater {
                    model: row.edited ? JSON.parse(row.versionsJson) : []
                    delegate: Text {
                        required property var modelData
                        width: column.width - 2 * Metrics.space12
                        wrapMode: Text.Wrap
                        text: Qt.formatTime(new Date(modelData.timestampMs), "HH:mm:ss") + " · " + (modelData.status === "read" ? qsTr("Przeczytano") : modelData.status === "delivered" ? qsTr("Dostarczono") : modelData.status === "received" ? qsTr("Odebrano") : qsTr("Wysłano"))
                        color: row.mutedForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.smallFontSize
                    }
                }
            }
            }
            Text {
                id: interactionLabel
                width: column.width - 24
                visible: !!row.interaction && row.interaction.state !== "sent" && row.interaction.state !== "cancelled"
                text: !row.interaction ? "" : row.interaction.state === "unknown" ? qsTr("Zmiana · wynik nieznany") : row.interaction.state === "failed" ? qsTr("Zmiana nie została wysłana") : qsTr("Zmiana w kolejce")
                color: row.mutedForeground
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.smallFontSize
            }
            BubbleButton {
                id: interactionButton
                visible: !!row.interaction && (row.interaction.state === "queued" || (row.interaction.state === "failed" && row.interaction.safe_retry))
                text: row.interaction && row.interaction.state === "queued" ? qsTr("Anuluj zmianę") : qsTr("Ponów zmianę")
                onClicked: root.adapter.changeOperation(row.interaction.operation_id, row.interaction.state !== "queued")
            }
            Item {
                id: footer
                width: column.width - 2 * Metrics.space12
                height: Math.max(reactionChips.height, statusRow.height)
                readonly property real reactionsWidth: reactionChips.children.reduce((sum, item) =>
                    sum + (item.objectName === "messageReaction" ? item.implicitWidth + Metrics.space4 : 0), 0)
                readonly property real naturalWidth: statusLabel.implicitWidth + (row.outgoing ? 20 : 0)
                    + (row.reactions.length ? reactionsWidth + Metrics.space8 : 0)
                readonly property real statusWidth: Math.min(width - Math.min(width * .38,
                    row.reactions.length ? reactionsWidth + Metrics.space4 : 0), statusLabel.implicitWidth + (row.outgoing ? 20 : 0))
                Flow {
                    id: reactionChips
                    width: Math.max(0, parent.width - footer.statusWidth - Metrics.space8)
                    y: 0
                    spacing: Metrics.space4
                    Repeater {
                        model: row.reactions
                        delegate: MessageButton {
                            id: reactionButton
                            required property var modelData
                            objectName: "messageReaction"
                            height: footerMetrics.height
                            font.pixelSize: Metrics.smallFontSize
                            font.bold: modelData.mine
                            foreground: row.mutedForeground
                            text: modelData.emoji + " " + modelData.count
                            checked: modelData.mine
                            Accessible.name: text + ": " + modelData.people.map(p => p.name).join(", ")
                            onClicked: root.actionsMessageId = root.actionsMessageId === row.messageId ? "" : row.messageId
                        }
                    }
                }
                Row {
                    id: statusRow
                    width: footer.statusWidth
                    x: parent.width - width
                    y: 0
                    spacing: Metrics.space4
                    UI.Glyph {
                        visible: row.outgoing
                        width: 16
                        height: 16
                        y: (parent.height - height) / 2
                        symbol: ["delivered", "read", "viewed"].includes(row.statusCode) ? "check" : "send"
                        color: row.mutedForeground
                    }
                    Text {
                        id: statusLabel
                        width: parent.width - (row.outgoing ? 20 : 0)
                        text: row.time + (row.expirationSeconds ? qsTr(" · Znikanie ") + row.expirationSeconds + " s" : "") + (row.edited ? qsTr(" · Edytowano") : "") + (row.outgoing && row.status ? " · " + row.status : "")
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignRight
                        color: row.mutedForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.smallFontSize
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }
    Connections {
        target: root.adapter
        function onJumpRequested(mid: string): void {
            root.followEnd = false;
            for (let i = 0; i < root.count; i++) if (root.adapter.messages.get(i).messageId === mid) {
                root.positionViewAtIndex(i, ListView.Center); root.forceLayout();
                root.forceActiveFocus(Qt.TabFocusReason); break;
            }
        }
        function onHistoryChanging(reset: bool): void {
            root.capture(reset);
            // Detach before a full clear while delegates may still be
            // incubating (opening a window and selecting another conversation).
            if (reset) root.resetting = true;
        }
        function onHistoryChanged(_reset: bool): void {
            root.resetting = false;
            if (!root.releasing) Qt.callLater(root.restoreCallback);
        }
    }
}
