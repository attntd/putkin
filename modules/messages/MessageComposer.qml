pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Item {
    id: root
    required property var adapter
    readonly property alias editor: editor
    property bool editingEnabled: false
    readonly property bool editing: adapter !== null && !!adapter.editingMessage
    readonly property string value: adapter ? adapter.composerText : ""
    function syncTyping(): void { if (adapter) adapter.editorActive = editingEnabled && visible && editor.activeFocus; }
    onValueChanged: { if (editor.text !== value) sync(); }
    onEditingEnabledChanged: syncTyping()
    onVisibleChanged: syncTyping()
    Component.onDestruction: { if (adapter) { adapter.editorActive = false; adapter.stopTyping(); } }
    implicitHeight: Math.min(144, Math.max(Metrics.controlHeight, editor.contentHeight + editor.topPadding + editor.bottomPadding)) + attachmentStrip.height + modeStrip.height
    function sync(): void { editor.text = value; }
    function handleReturn(event: var, composing: bool): void {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return;
        if (composing || (event.modifiers & Qt.ShiftModifier)) return;
        event.accepted = true;
        if (!event.isAutoRepeat && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.KeypadModifier) && adapter) adapter.sendComposer();
    }
    Row {
        id: modeStrip
        width: parent.width
        height: visible ? 40 : 0
        visible: root.editing || (root.adapter && !!root.adapter.quotedMessage)
        spacing: Metrics.space8
        Text {
            width: Math.max(0, parent.width - cancelMode.width - Metrics.space8)
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: root.editing ? qsTr("Edycja wiadomości") : root.adapter && root.adapter.quotedMessage ? root.adapter.quotedMessage.author + ": " + root.adapter.quotedMessage.text : ""
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.smallFontSize
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        UI.NavigationButton {
            id: cancelMode
            objectName: "cancelMessageMode"
            visible: root.editing || (root.adapter && !!root.adapter.quotedMessage)
            width: visible ? implicitWidth : 0
            text: qsTr("Anuluj")
            enabled: !root.adapter || !root.adapter.editBusy
            onClicked: { if (root.editing) root.adapter.cancelEdit(); else root.adapter.cancelQuote(); editor.forceActiveFocus(focusReason); }
        }
    }
    MentionPicker {
        id: members
        adapter: root.adapter
        editor: root.editor
    }
    Controls.ScrollView {
        anchors { left: attachButton.right; right: parent.right; top: attachmentStrip.bottom; bottom: parent.bottom; leftMargin: Metrics.space8 }
        clip: true
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        Controls.ScrollBar.vertical: UI.ScrollBar {}
        Controls.TextArea {
            id: editor
            objectName: "messageEditor"
            enabled: root.adapter !== null && root.adapter.draftReady
            readOnly: root.adapter !== null && root.adapter.composerBusy
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            persistentSelection: true
            leftPadding: Metrics.space12
            rightPadding: Metrics.space12
            topPadding: Math.max(Metrics.space4, Math.floor((Metrics.controlHeight - fontMetrics.height) / 2))
            bottomPadding: topPadding
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.fontSize
            color: Theme.text
            selectionColor: accent.color
            selectedTextColor: accent.foreground
            Accessible.name: qsTr("Wiadomość")
            Keys.forwardTo: [input]
            Keys.onPressed: event => {
                if (members.handleKey(event)) return;
                if (event.key === Qt.Key_Escape && root.editing) { root.adapter.cancelEdit(); return; }
                if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier) && ((event.modifiers & Qt.ShiftModifier) || !editor.canPaste) && root.adapter) {
                    event.accepted = true; root.adapter.pasteImage();
                } else root.handleReturn(event, editor.inputMethodComposing || editor.preeditText.length > 0);
            }
            onActiveFocusChanged: root.syncTyping()
            onTextEdited: { if (activeFocus && root.adapter && text !== root.value) root.adapter.editComposer(text); }
            UI.ControlInput { id: input; control: editor }
            UI.AccentCoordinates { id: accent; item: editor }
            background: Rectangle {
                color: Theme.background
                border.color: Theme.border
                border.width: Metrics.borderWidth
                UI.FocusIndicator { control: editor }
            }
        }
    }
    FontMetrics { id: fontMetrics; font: editor.font }
    UI.NavigationButton {
        id: attachButton
        objectName: "attachFiles"
        anchors { left: parent.left; bottom: parent.bottom }
        width: Metrics.controlHeight
        height: Metrics.controlHeight
        text: qsTr("Załącz pliki")
        enabled: root.adapter !== null && root.adapter.canSend && !root.editing
        contentItem: UI.Glyph { symbol: "add"; color: attachButton.foreground }
        rightTarget: editor
        onClicked: files.open()
    }
    FileDialog {
        id: files
        objectName: "attachmentFileDialog"
        title: qsTr("Załącz pliki")
        fileMode: FileDialog.OpenFiles
        onAccepted: root.adapter.attachFiles(selectedFiles.map(value => value.toString()))
    }
    Flickable {
        id: attachmentStrip
        y: modeStrip.height
        width: parent.width
        height: !root.editing && root.adapter && ((root.adapter.draftAttachments || []).length > 0 || root.adapter.mediaBusy > 0) ? 44 : 0
        contentWidth: attachments.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Row {
            id: attachments
            spacing: Metrics.space8
            Repeater {
                model: root.adapter ? root.adapter.draftAttachments || [] : []
                delegate: UI.NavigationButton {
                    required property var modelData
                    objectName: "removeAttachment"
                    text: modelData.filename + " ×"
                    enabled: root.adapter && root.adapter.canSend
                    onClicked: root.adapter.removeAttachment(modelData.attachment_id)
                }
            }
            UI.NavigationButton {
                visible: root.adapter && root.adapter.mediaBusy > 0
                width: visible ? implicitWidth : 0
                text: qsTr("Przygotowywanie · Anuluj")
                onClicked: root.adapter.cancelMedia()
            }
        }
    }
    DropArea {
        anchors.fill: parent
        onEntered: drag => { drag.accepted = drag.hasUrls && root.adapter !== null && root.adapter.canSend; }
        onDropped: drop => {
            if (drop.hasUrls && root.adapter) { root.adapter.attachFiles(drop.urls.map(value => value.toString())); drop.acceptProposedAction(); }
        }
    }
    Connections {
        target: root.adapter
        function onComposerLoaded(): void { root.sync(); editor.forceActiveFocus(Qt.TabFocusReason); }
        function onDraftReadyChanged(): void { if (!root.adapter.draftReady) editor.text = ""; }
        function onDraftLoaded(): void { root.sync(); }
        function onSelectedRouteChanged(): void { root.sync(); }
        function onDraftTextChanged(): void { if (!root.editing && !editor.activeFocus) root.sync(); }
    }
    onAdapterChanged: sync()
    Component.onCompleted: sync()
}
