pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var settings
    property Item upTarget: null
    property real maximumHeight: Metrics.settingsHeight
    property string selectedAction: "launcher"
    readonly property var selected: settings ? settings.draft.find(row => row.action === selectedAction) : null
    readonly property Item firstControl: actions
    readonly property Item lastControl: cancel
    spacing: Metrics.space12
    signal dismissed()
    signal ensureVisible(Item item)
    function select(action: string): void {
        selectedAction = action;
        shortcut.text = selected ? selected.shortcut : "";
        command.text = selected ? selected.command : "";
    }

    UI.PanelText { width: parent.width; text: qsTr("Działanie"); font.bold: true }
    Controls.ScrollView {
        width: parent.width
        height: Math.min(196, Math.max(Metrics.controlHeight, root.maximumHeight - Metrics.space12))
        contentWidth: availableWidth
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        ListView {
            id: actions
            objectName: "keyboardActions"
            clip: true
            model: root.settings ? root.settings.catalog : []
            currentIndex: 0
            spacing: Metrics.space4
            boundsBehavior: Flickable.StopAtBounds
            KeyNavigation.tab: shortcut
            KeyNavigation.backtab: root.upTarget
            onActiveFocusChanged: { if (activeFocus) root.ensureVisible(actions); }
            function choose(): void {
                const action = model[currentIndex];
                if (action) { root.select(action.id); shortcut.forceActiveFocus(Qt.TabFocusReason); }
            }
            Keys.onPressed: event => {
                if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
                if (event.key === Qt.Key_J || event.key === Qt.Key_Down) currentIndex = Math.min(count - 1, currentIndex + 1);
                else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    if (currentIndex === 0 && root.upTarget) root.upTarget.forceActiveFocus(Qt.TabFocusReason);
                    else currentIndex = Math.max(0, currentIndex - 1);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_L || event.key === Qt.Key_Right) choose();
                else if ((event.key === Qt.Key_H || event.key === Qt.Key_Left) && root.upTarget) root.upTarget.forceActiveFocus(Qt.TabFocusReason);
                else return;
                positionViewAtIndex(currentIndex, ListView.Contain);
                event.accepted = true;
            }
            delegate: UI.Button {
                required property var modelData
                required property int index
                width: ListView.view.width
                text: modelData.group + " · " + modelData.title
                checked: root.selectedAction === modelData.id
                highlighted: actions.activeFocus && actions.currentIndex === index
                focusPolicy: Qt.NoFocus
                onClicked: { const reason = focusReason; actions.currentIndex = index; root.select(modelData.id); shortcut.forceActiveFocus(reason); }
            }
        }
    }
    UI.PanelText {
        width: parent.width
        text: root.settings ? root.settings.catalog.find(action => action.id === root.selectedAction).title : qsTr("Klawiatura niedostępna")
        font.bold: true
    }
    UI.PanelText { width: parent.width; text: qsTr("Skrót klawiszowy") }
    UI.TextField {
        id: shortcut
        objectName: "shortcutField"
        width: parent.width
        enabled: root.settings && root.settings.ready && !root.settings.saving
        text: root.selected ? root.selected.shortcut : ""
        Accessible.name: qsTr("Skrót klawiszowy")
        KeyNavigation.tab: command
        KeyNavigation.backtab: actions
        onTextEdited: root.settings.setBinding(root.selectedAction, "shortcut", text)
        onAccepted: command.forceActiveFocus(Qt.TabFocusReason)
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.PanelText { width: parent.width; text: qsTr("Komenda :") }
    UI.TextField {
        id: command
        objectName: "commandField"
        width: parent.width
        enabled: shortcut.enabled
        text: root.selected ? root.selected.command : ""
        Accessible.name: qsTr("Komenda")
        KeyNavigation.tab: reset
        KeyNavigation.backtab: shortcut
        onTextEdited: root.settings.setBinding(root.selectedAction, "command", text)
        onAccepted: { if (save.enabled) save.forceActiveFocus(Qt.TabFocusReason); }
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.PanelText {
        objectName: "keyboardProblem"
        width: parent.width
        visible: text.length > 0
        text: root.settings ? root.settings.problem : ""
        color: Theme.error
    }
    UI.NavigationButton {
        id: reset
        objectName: "resetKeyboardButton"
        width: parent.width
        enabled: shortcut.enabled
        text: qsTr("Przywróć domyślne")
        upTarget: command
        downTarget: reload.visible ? reload : save
        KeyNavigation.tab: reload.visible ? reload : save
        KeyNavigation.backtab: command
        onClicked: root.settings.resetDraft()
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.NavigationButton {
        id: reload
        objectName: "reloadKeyboardButton"
        width: parent.width
        visible: root.settings && (root.settings.conflict || root.settings.readProblem.length > 0 || root.settings.applyProblem.length > 0)
        enabled: root.settings && !root.settings.saving
        text: qsTr("Wczytaj ponownie")
        upTarget: reset
        downTarget: save.enabled ? save : cancel
        KeyNavigation.tab: save
        KeyNavigation.backtab: reset
        onClicked: root.settings.useLatest()
        onEnsureVisible: item => root.ensureVisible(item)
    }
    Row {
        width: parent.width
        spacing: Metrics.space12
        UI.NavigationButton {
            id: save
            objectName: "saveKeyboardButton"
            width: (parent.width - parent.spacing) / 2
            text: qsTr("Zapisz")
            highlighted: true
            enabled: root.settings && root.settings.canSave
            rightTarget: cancel
            upTarget: reload.visible ? reload : reset
            KeyNavigation.tab: cancel
            KeyNavigation.backtab: upTarget
            onClicked: root.settings.save()
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: cancel
            objectName: "cancelKeyboardButton"
            width: save.width
            text: qsTr("Anuluj")
            leftTarget: save
            upTarget: save.upTarget
            KeyNavigation.tab: root.upTarget
            KeyNavigation.backtab: save
            onClicked: root.dismissed()
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    Connections { target: root.settings; function onDraftReplaced(): void { root.select(root.selectedAction); } }
}
