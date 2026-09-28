pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI
import "../../assets/signal/Emoji.js" as Emoji

Column {
    id: root
    property bool expanded: false
    property string ownEmoji: ""
    property int reason: Qt.MouseFocusReason
    readonly property var preferred: ["❤️", "👍", "👎", "😂", "😮", "😢"]
    readonly property bool extra: ownEmoji !== "" && preferred.indexOf(ownEmoji) < 0
    property real availableHeight: 320
    readonly property var results: Emoji.items.filter(e => !search.text || e[0].includes(search.text)
        || e[1].includes(search.text.toLocaleLowerCase()))
    signal chosen(string emoji, int reason)
    signal dismissed()
    spacing: Metrics.space8
    component EmojiButton: UI.NavigationButton {
        id: button
        background: UI.AccentRectangle {
            radius: height / 2
            color: button.checked ? Theme.accent : button.down ? Theme.border : button.hovered ? Theme.surfaceHover : "transparent"
            accentFill: button.checked
            accentOutline: false
            UI.FocusIndicator { control: button; radius: parent.height / 2 }
        }
    }
    function focusFirst(): void {
        if (expanded) search.forceActiveFocus(reason);
        else quick.itemAt(0).forceActiveFocus(reason);
    }
    Row {
        visible: !root.expanded
        Repeater {
            id: quick
            model: root.preferred.concat([root.extra ? root.ownEmoji : "+"])
            delegate: EmojiButton {
                required property string modelData
                required property int index
                objectName: index === 6 && !root.extra ? "allReactions" : "reactionChoice"
                width: root.width / 7; height: 40
                padding: 0; tooltip: ""
                text: modelData
                font.pixelSize: 23
                checked: modelData === root.ownEmoji
                Accessible.name: index === 6 && !root.extra ? qsTr("Wszystkie emoji") : checked ? qsTr("Usuń reakcję ") + text : qsTr("Reakcja ") + text
                leftTarget: index > 0 ? quick.itemAt(index - 1) : null
                rightTarget: index < 6 ? quick.itemAt(index + 1) : null
                onClicked: {
                    if (index === 6 && !root.extra) { root.reason = focusReason; root.expanded = true; root.focusFirst(); }
                    else root.chosen(modelData, focusReason);
                }
            }
        }
    }
    UI.TextField {
        id: search
        objectName: "emojiSearch"
        visible: root.expanded
        width: root.width
        Accessible.name: qsTr("Szukaj emoji")
        onTextChanged: grid.currentIndex = 0
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                if (grid.currentItem) grid.currentItem.forceActiveFocus(Qt.TabFocusReason);
                event.accepted = true;
            }
        }
    }
    GridView {
        id: grid
        objectName: "emojiGrid"
        visible: root.expanded
        width: root.width
        height: Math.min(240, Math.max(40, root.availableHeight - search.height - root.spacing))
        cellWidth: width / 7; cellHeight: 40
        clip: true
        model: root.expanded ? root.results : []
        keyNavigationEnabled: false
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: UI.ScrollBar {}
        delegate: EmojiButton {
            required property var modelData
            required property int index
            objectName: "emojiChoice"
            width: grid.cellWidth; height: grid.cellHeight
            padding: 0; tooltip: ""
            text: modelData[0]
            font.pixelSize: 23
            checked: text === root.ownEmoji
            Accessible.name: modelData[1]
            onClicked: root.chosen(text, focusReason)
            Keys.onPressed: event => {
                if (event.modifiers !== Qt.NoModifier) return;
                let step = 0;
                if (event.key === Qt.Key_H || event.key === Qt.Key_Left) step = -1;
                else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) step = 1;
                else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) step = 7;
                else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) step = -7;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (!event.isAutoRepeat) root.chosen(text, Qt.TabFocusReason);
                    event.accepted = true; return;
                } else return;
                if (index + step < 0 && step === -7) search.forceActiveFocus(Qt.TabFocusReason);
                else {
                    grid.currentIndex = Math.max(0, Math.min(grid.count - 1, index + step));
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
                    grid.forceLayout();
                    if (grid.currentItem) grid.currentItem.forceActiveFocus(Qt.TabFocusReason);
                }
                event.accepted = true;
            }
        }
    }
}
