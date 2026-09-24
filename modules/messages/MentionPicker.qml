pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Controls.Popup {
    id: root
    required property var adapter
    required property var editor
    property int start: -1
    property int end: -1
    property var candidates: []
    property bool applying: false
    objectName: "mentionPicker"
    y: -height
    width: Math.min(parent.width, 320)
    height: Math.min(240, candidates.length * Metrics.controlHeight + padding * 2)
    padding: Metrics.space8
    modal: false
    focus: false
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    background: UI.PanelFrame {}

    function refresh(): void {
        if (applying) return;
        const match = editor.text.slice(0, editor.cursorPosition).match(/(^|[\s(])@([^\s@]*)$/);
        const ranges = adapter ? adapter.editingMessage ? adapter.editMentions : adapter.composeMentions : [];
        if (!adapter || !editor.activeFocus || editor.readOnly || editor.inputMethodComposing || editor.preeditText.length
                || editor.selectionStart !== editor.selectionEnd || !match
                || ranges.some(m => editor.cursorPosition > m.start && editor.cursorPosition <= m.start + m.length)) {
            close(); return;
        }
        start = editor.cursorPosition - match[2].length - 1;
        end = editor.cursorPosition + editor.text.slice(editor.cursorPosition).match(/^[^\s@]*/)[0].length;
        const query = match[2].toLocaleLowerCase();
        candidates = adapter.mentionMembers.filter(m => m.name.toLocaleLowerCase().includes(query));
        if (!candidates.length) { close(); return; }
        memberList.currentIndex = 0;
        open();
    }
    function choose(index: int, reason: int): void {
        if (!visible || index < 0 || index >= candidates.length || start < 0) return;
        const member = candidates[index], cursor = start + member.name.length + 2;
        applying = true;
        adapter.addMention(member, start, end - start);
        editor.cursorPosition = cursor;
        close();
        editor.forceActiveFocus(reason);
        editor.focusReason = reason;
        applying = false;
    }
    function move(delta: int, focusList = false): void {
        memberList.currentIndex = Math.max(0, Math.min(candidates.length - 1, memberList.currentIndex + delta));
        memberList.positionViewAtIndex(memberList.currentIndex, ListView.Contain);
        if (focusList) {
            memberList.forceLayout();
            if (memberList.currentItem) memberList.currentItem.forceActiveFocus(Qt.TabFocusReason);
        }
    }
    function handleKey(event: var, inList = false): bool {
        if (!visible || editor.inputMethodComposing || editor.preeditText.length) return false;
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return false;
        if (event.key === Qt.Key_Escape || (inList && (event.key === Qt.Key_H || event.key === Qt.Key_Left))) {
            close(); editor.forceActiveFocus(Qt.TabFocusReason);
        } else if (event.key === Qt.Key_Down || (inList && event.key === Qt.Key_J)) move(1, inList);
        else if (event.key === Qt.Key_Up || (inList && event.key === Qt.Key_K)) move(-1, inList);
        else if (event.key === Qt.Key_Tab) move(0, true);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || (inList && (event.key === Qt.Key_L || event.key === Qt.Key_Right))) {
            if (!event.isAutoRepeat) choose(memberList.currentIndex, Qt.TabFocusReason);
        } else return false;
        event.accepted = true;
        return true;
    }
    contentItem: ListView {
        id: memberList
        readonly property bool accentScope: true
        objectName: "mentionList"
        clip: true
        model: root.candidates
        keyNavigationEnabled: false
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: UI.ScrollBar {}
        delegate: UI.Button {
            required property var modelData
            required property int index
            objectName: "mentionChoice"
            width: memberList.width
            text: modelData.name
            highlighted: memberList.currentIndex === index
            Keys.onPressed: event => root.handleKey(event, true)
            onClicked: root.choose(index, focusReason)
        }
    }
    Connections {
        target: root.editor
        function onCursorPositionChanged(): void { root.refresh(); }
        function onTextEdited(): void { root.refresh(); }
        function onInputMethodComposingChanged(): void { root.refresh(); }
    }
    Connections {
        target: root.adapter
        function onSelectedRouteChanged(): void { root.close(); }
        function onComposerLoaded(): void { root.close(); }
    }
}
