pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../core/Icons.js" as Icons
import "../../components" as UI

Column {
    id: root
    required property var handle
    required property Component menuComponent
    required property Item backControl
    property var opener: null
    property string title: ""
    property var selected: null
    property bool hadFocus: false
    property bool focusedOnce: false
    readonly property var entries: opener && opener.entries ? opener.entries.values : []
    signal descend(var entry, int reason)
    signal activated(var entry)
    signal backRequested()
    signal ensureVisible(Item item)
    signal entriesUpdated()
    width: parent ? parent.width : 0
    spacing: Metrics.space4

    function focusEntry(entry: var, reason = Qt.TabFocusReason): void {
        const index = entries.indexOf(entry);
        const button = index >= 0 ? buttons.itemAt(index) : null;
        if (button && button.enabled) button.forceActiveFocus(reason);
        else moveSelection(-1, 1, reason);
    }
    function moveSelection(index: int, delta: int, reason = Qt.TabFocusReason): void {
        for (let i = index + delta; i >= 0 && i < entries.length; i += delta) {
            const button = buttons.itemAt(i);
            if (button && button.enabled) {
                button.forceActiveFocus(reason);
                return;
            }
        }
        backControl.forceActiveFocus(reason);
    }
    function focusInitial(reason = Qt.TabFocusReason): void {
        // Repeater delegates can finish in a different order during incubation.
        // Do not select a later entry or the back button while earlier items load.
        for (let i = 0; i < entries.length; ++i)
            if (!buttons.itemAt(i)) return;
        focusEntry(selected, reason);
    }
    function repair(): void {
        entriesUpdated();
        if (visible && hadFocus && (!selected || entries.indexOf(selected) < 0 || !selected.enabled || selected.isSeparator))
            focusInitial();
    }
    onEntriesChanged: repairLater.restart()
    Component.onCompleted: { opener = menuComponent.createObject(root, { handle: handle }); }
    Timer { id: repairLater; interval: 0; onTriggered: root.repair() }
    Component.onDestruction: { repairLater.stop(); if (opener) opener.destroy(); }
    UI.PanelText {
        width: parent.width
        visible: root.entries.length === 0
        text: qsTr("Brak dostępnych pozycji menu")
        color: Theme.textMuted
    }
    Repeater {
        id: buttons
        model: root.opener ? root.opener.entries : null
        onItemAdded: repairLater.restart()
        UI.Button {
            id: button
            required property var modelData
            required property int index
            objectName: "trayMenuEntry-" + index
            width: root.width
            implicitHeight: modelData.isSeparator ? Metrics.space8 : Metrics.controlHeight
            enabled: modelData.enabled && !modelData.isSeparator
            text: modelData.text || qsTr("Bez nazwy")
            tooltip: text
            Accessible.role: modelData.buttonType === 1 ? Accessible.CheckBox
                : modelData.buttonType === 2 ? Accessible.RadioButton : Accessible.MenuItem
            Accessible.checkable: modelData.buttonType !== 0
            Accessible.checked: modelData.checkState === Qt.Checked
            onClicked: {
                if (modelData.hasChildren) root.descend(modelData, focusReason);
                else root.activated(modelData);
            }
            onActiveFocusChanged: {
                if (activeFocus) {
                    root.selected = modelData;
                    root.hadFocus = true;
                    root.focusedOnce = true;
                    root.ensureVisible(button);
                }
            }
            onEnabledChanged: { if (!enabled && root.selected === modelData) repairLater.restart(); }
            Keys.onPressed: event => {
                if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier
                        && event.modifiers !== Qt.ShiftModifier) return;
                if (event.key === Qt.Key_J || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && event.modifiers === Qt.NoModifier))
                    root.moveSelection(index, 1);
                else if (event.key === Qt.Key_K || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_Tab)
                    root.moveSelection(index, -1);
                else if (event.key === Qt.Key_H || event.key === Qt.Key_Left)
                    root.backRequested();
                else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                    if (modelData.hasChildren) root.descend(modelData, Qt.TabFocusReason);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (!event.isAutoRepeat) button.click();
                } else return;
                event.accepted = true;
            }
            contentItem: Row {
                spacing: Metrics.space8
                visible: !button.modelData.isSeparator
                UI.Glyph {
                    objectName: "trayMenuIcon"
                    width: slotSize; height: slotSize
                    anchors.verticalCenter: parent.verticalCenter
                    symbol: button.modelData.buttonType === 0 ? Icons.menu(button.modelData.icon) : button.modelData.checkState === Qt.Checked
                        ? (button.modelData.buttonType === 2 ? "radio_button_checked" : "check_box")
                        : button.modelData.checkState === Qt.PartiallyChecked ? "indeterminate_check_box"
                        : button.modelData.buttonType === 2 ? "radio_button_unchecked" : "check_box_outline_blank"
                    color: button.foreground
                }
                Text {
                    width: Math.max(1, button.availableWidth - 56 - Metrics.space16); height: parent.height
                    text: button.text; textFormat: Text.PlainText
                    elide: Text.ElideRight; font: button.font; color: button.foreground
                    verticalAlignment: Text.AlignVCenter
                }
                UI.Glyph {
                    width: slotSize; height: slotSize
                    anchors.verticalCenter: parent.verticalCenter
                    symbol: button.modelData.hasChildren ? "chevron_right" : ""
                    color: button.foreground
                }
            }
            background: Rectangle {
                color: button.modelData.isSeparator ? "transparent" : button.fillColor
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: Metrics.borderWidth; color: Theme.border
                    visible: button.modelData.isSeparator
                }
                UI.FocusIndicator {
                    control: button
                    anchors.margins: -Metrics.focusOffset
                }
            }
        }
    }
}
