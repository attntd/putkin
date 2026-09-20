pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var sessionService
    property string confirmation: ""
    property var controls: []
    readonly property var actions: [
        { id: "logout", title: qsTr("Wyloguj"), icon: "logout" },
        { id: "reboot", title: qsTr("Restart"), icon: "restart" },
        { id: "poweroff", title: qsTr("Wyłącz"), icon: "power" },
        { id: "suspend", title: qsTr("Uśpij"), icon: "sleep" }
    ]
    spacing: Metrics.space12
    signal dismissed()
    signal requested(string surface)
    signal ensureVisible(Item item)
    function title(action: string): string { const value = actions.find(item => item.id === action); return value ? value.title : ""; }
    function button(index: int): Item { return controls[index] || null; }
    function rebuildNavigation(): void {
        const items = [];
        for (let i = 0; i < choices.count; ++i) {
            const item = choices.itemAt(i) as ActionRow;
            items.push(item ? item.control : null);
        }
        controls = items;
    }
    function focusInitial(reason = Qt.TabFocusReason): void {
        if (confirmation) cancel.forceActiveFocus(reason);
        else {
            for (let i = 0; i < actions.length; ++i) {
                const item = button(i);
                if (item && item.enabled) { item.forceActiveFocus(reason); return; }
            }
            close.forceActiveFocus(reason);
        }
    }
    function dismissOrCollapse(reason = Qt.TabFocusReason): void {
        if (confirmation) { confirmation = ""; Qt.callLater(focusInitial, reason); }
        else dismissed();
    }
    function choose(action: string, reason: int): void {
        if (sessionService.busy || !sessionService.capability(action).available) return;
        if (action === "suspend") { sessionService.request(action); close.forceActiveFocus(reason); return; }
        confirmation = action;
        Qt.callLater(focusInitial, reason);
    }
    onEnabledChanged: { if (!enabled) confirmation = ""; }

    UI.PanelText { width: parent.width; text: qsTr("Zasilanie"); font.bold: true }
    UI.PanelText {
        width: parent.width
        visible: root.confirmation.length > 0
        text: qsTr("%1? Niezapisana praca może zostać utracona.").arg(root.title(root.confirmation))
    }
    Grid {
        id: grid
        width: parent.width
        columns: width >= 320 ? 4 : 2
        spacing: Metrics.space8
        visible: !root.confirmation
        Repeater {
            id: choices
            model: root.actions
            delegate: ActionRow {}
            onItemAdded: root.rebuildNavigation()
            onItemRemoved: root.rebuildNavigation()
        }
    }
    component ActionRow: Item {
        id: row
        required property var modelData
        required property int index
        readonly property alias control: action
        readonly property var capability: root.sessionService.capability(modelData.id)
        width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
        height: action.implicitHeight
        UI.ActionTile {
            id: action
            objectName: "power-" + row.modelData.id
            width: parent.width
            text: row.modelData.title
            symbol: ["logout", "restart_alt", "power_settings_new", "bedtime"][row.index]
            enabled: row.capability.available && !root.sessionService.busy
            Accessible.description: row.capability.reason
            leftTarget: row.index % grid.columns > 0 ? root.button(row.index - 1) : null
            rightTarget: row.index % grid.columns + 1 < grid.columns ? root.button(row.index + 1) : null
            upTarget: row.index >= grid.columns ? root.button(row.index - grid.columns) : close
            downTarget: row.index + grid.columns < root.actions.length ? root.button(row.index + grid.columns) : close
            KeyNavigation.tab: row.index < root.actions.length - 1 ? root.button(row.index + 1) : close
            KeyNavigation.backtab: row.index > 0 ? root.button(row.index - 1) : close
            onClicked: root.choose(row.modelData.id, focusReason)
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    Row {
        width: parent.width
        spacing: Metrics.space12
        visible: root.confirmation.length > 0
        UI.NavigationButton {
            id: cancel
            objectName: "powerCancel"
            width: (parent.width - parent.spacing) / 2
            text: qsTr("Anuluj")
            rightTarget: confirm
            downTarget: close
            KeyNavigation.tab: confirm.enabled ? confirm : close
            KeyNavigation.backtab: close
            onClicked: root.dismissOrCollapse(focusReason)
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: confirm
            objectName: "powerConfirm"
            width: cancel.width
            text: root.title(root.confirmation)
            enabled: !!root.confirmation && !root.sessionService.busy && root.sessionService.capability(root.confirmation).available
            leftTarget: cancel
            downTarget: close
            KeyNavigation.tab: close
            KeyNavigation.backtab: cancel
            onClicked: {
                const reason = focusReason;
                const action = root.confirmation;
                root.confirmation = "";
                root.sessionService.request(action);
                close.forceActiveFocus(reason);
            }
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    UI.NavigationButton {
        id: close
        objectName: "powerClose"
        width: parent.width
        text: qsTr("Zamknij")
        upTarget: root.confirmation ? cancel : root.button(3)
        downTarget: root.confirmation ? cancel : root.button(0)
        KeyNavigation.tab: downTarget
        KeyNavigation.backtab: upTarget
        onClicked: root.dismissed()
        onEnsureVisible: item => root.ensureVisible(item)
    }
}
