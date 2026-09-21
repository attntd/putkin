import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var session
    property Item previousControl: null
    property Item nextControl: null
    readonly property alias editor: editor
    spacing: Metrics.space8
    signal controlFocused(Item control)
    signal collapsed()
    function focusEditor(reason = Qt.TabFocusReason): void { editor.forceActiveFocus(reason); }
    function sync(): void { if (session && editor.text !== session.text) editor.text = session.text; }
    function handleReturn(event: var, composing: bool): void {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return;
        if (composing || (event.modifiers & Qt.ShiftModifier)) return;
        event.accepted = true;
        if (!event.isAutoRepeat && event.modifiers === Qt.NoModifier && session) session.send();
    }
    Controls.ScrollView {
        width: parent.width
        height: 84
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        Controls.TextArea {
            id: editor
            objectName: "notificationReplyEditor"
            enabled: !!root.session && root.session.active
            readOnly: !root.session || !root.session.editable
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            padding: Metrics.space8
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.fontSize
            color: Theme.text
            selectionColor: accent.color
            selectedTextColor: accent.foreground
            Accessible.name: qsTr("Odpowiedź")
            KeyNavigation.tab: sendButton.enabled ? sendButton : root.nextControl
            KeyNavigation.backtab: root.previousControl
            Keys.forwardTo: [input]
            Keys.onPressed: event => root.handleReturn(event, editor.inputMethodComposing || editor.preeditText.length > 0)
            Keys.onEscapePressed: { root.session.editing = false; root.collapsed(); }
            onTextEdited: { if (root.session) root.session.edit(text); }
            onActiveFocusChanged: {
                if (root.session) root.session.editing = activeFocus;
                if (activeFocus) root.controlFocused(editor);
            }
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
    Row {
        width: parent.width
        spacing: Metrics.space8
        UI.PanelText {
            width: Math.max(1, parent.width - sendButton.width - parent.spacing)
            text: root.session ? root.session.statusText : ""
            color: root.session && ["failed", "unknown"].includes(root.session.state) ? Theme.error : Theme.textMuted
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        UI.NavigationButton {
            id: sendButton
            objectName: "notificationReplySend"
            width: 88
            text: root.session && root.session.canRetry ? qsTr("Ponów") : qsTr("Wyślij")
            enabled: !!root.session && (root.session.canSend || root.session.canRetry)
            highlighted: true
            upTarget: editor
            KeyNavigation.backtab: editor
            KeyNavigation.tab: root.nextControl
            onClicked: { if (root.session.canRetry) root.session.retry(); else root.session.send(); }
            onEnsureVisible: item => root.controlFocused(item)
        }
    }
    Connections { target: root.session; function onTextChanged(): void { root.sync(); } }
    onSessionChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: { if (session) session.editing = false; }
}
