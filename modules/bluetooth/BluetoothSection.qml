pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var bluetooth
    required property Item previousControl
    required property Item nextControl
    property bool expanded: false
    property Item lastFocused: null
    property int navigationRevision: 0
    readonly property Item firstControl: radio.enabled ? radio : expand
    readonly property Item lastControl: expanded ? manager : expand
    signal ensureVisible(Item item)
    signal handoffRequested()
    spacing: Metrics.space8

    function reveal(item: Item): void { lastFocused = item; ensureVisible(item); }
    function rowAt(repeater: var, index: int): Item {
        return navigationRevision >= 0 && repeater ? repeater.itemAt(index) : null;
    }
    function firstDevice(): Item { return devices.count && bluetooth.radioEnabled ? rowAt(devices, 0) : manager; }
    function lastDevice(): Item { return devices.count && bluetooth.radioEnabled ? rowAt(devices, devices.count - 1) : lastAdapter(); }
    function lastAdapter(): Item { return adapters.count > 1 ? rowAt(adapters, adapters.count - 1) : expand; }
    function collapse(): bool {
        if (!expanded) return false;
        expanded = false;
        expand.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }
    UI.ModuleRow {
        width: parent.width
        UI.ModuleButton {
            id: radio
            objectName: "bluetoothRadio"
            width: 152
            text: qsTr("Bluetooth")
            symbol: "bluetooth"
            foreground: root.bluetooth.connectedCount > 0 ? accentColor : Theme.textMuted
            enabled: root.bluetooth.canRequest && !root.bluetooth.blocked
            rightTarget: expand
            upTarget: root.previousControl
            downTarget: expand.downTarget
            KeyNavigation.tab: expand
            KeyNavigation.backtab: root.previousControl
            onClicked: root.bluetooth.setEnabled(!root.bluetooth.radioEnabled)
            onEnsureVisible: item => root.reveal(item)
        }
        UI.ModuleButton {
            id: expand
            objectName: "bluetoothExpand"
            width: parent.width - radio.width
            arrow: true
            expanded: root.expanded
            text: root.bluetooth.busy ? qsTr("Łączenie…") : !root.bluetooth.available ? "—" : !root.bluetooth.radioEnabled ? qsTr("Wył.")
                : root.bluetooth.connectedCount > 0 ? qsTr("Połączono") : qsTr("Wł.")
            tooltip: qsTr("Sparowane urządzenia Bluetooth")
            leftTarget: radio.enabled ? radio : null
            upTarget: root.previousControl
            downTarget: root.expanded ? adapters.count > 1 ? root.rowAt(adapters, 0) : root.firstDevice() : root.nextControl
            KeyNavigation.tab: downTarget
            KeyNavigation.backtab: radio.enabled ? radio : root.previousControl
            onClicked: root.expanded = !root.expanded
            onEnsureVisible: item => root.reveal(item)
        }
    }
    UI.FadeColumn {
        width: parent.width
        shown: root.expanded
        spacing: Metrics.space8
        UI.PanelText {
            width: parent.width
            textFormat: Text.PlainText
            text: root.bluetooth.adapter ? qsTr("Adapter · ") + root.bluetooth.adapterLabel(root.bluetooth.adapter) : ""
            visible: adapters.count > 1 && text.length > 0
            color: Theme.textMuted
        }
        Column {
            width: parent.width
            visible: adapters.count > 1
            spacing: Metrics.space4
            Repeater {
                id: adapters
                model: root.bluetooth.adapters
                UI.NavigationButton {
                    id: adapterRow
                    required property var modelData
                    required property int index
                    objectName: "bluetoothAdapter-" + modelData.adapterId
                    width: root.width
                    text: root.bluetooth.adapterLabel(modelData)
                    trailingIcon: root.bluetooth.adapter === modelData ? "check" : ""
                    highlighted: root.bluetooth.adapter === modelData
                    upTarget: index > 0 ? root.rowAt(adapters, index - 1) : expand
                    downTarget: index + 1 < adapters.count ? root.rowAt(adapters, index + 1) : root.firstDevice()
                    KeyNavigation.tab: downTarget
                    KeyNavigation.backtab: upTarget
                    onClicked: root.bluetooth.selectAdapter(modelData)
                    onEnsureVisible: item => root.reveal(item)
                    contentItem: UI.IconLabel {
                        text: adapterRow.text
                        trailingIcon: adapterRow.trailingIcon
                        font: adapterRow.font
                        color: adapterRow.foreground
                        horizontalAlignment: Text.AlignLeft
                    }
                }
                onItemAdded: root.navigationRevision++
                onItemRemoved: { root.navigationRevision++; recover.restart(); }
            }
        }
        Repeater {
            id: devices
            model: root.bluetooth.deviceModel
            UI.NavigationButton {
                id: entry
                required property var device
                required property int index
                objectName: "bluetoothDevice-" + index
                width: root.width
                implicitHeight: Metrics.controlHeight
                enabled: root.bluetooth.radioEnabled && !!device && !!device.paired && !device.blocked
                highlighted: !!device && !!device.connected && root.bluetooth.radioEnabled
                text: root.bluetooth.label(device)
                tooltip: text + " · " + (device ? device.address || "" : "") + " · " + root.bluetooth.deviceStatus(device)
                    + " · " + root.bluetooth.batteryText(device)
                Accessible.description: tooltip
                upTarget: index > 0 ? root.rowAt(devices, index - 1) : root.lastAdapter()
                downTarget: index + 1 < devices.count ? root.rowAt(devices, index + 1) : manager
                KeyNavigation.tab: downTarget
                KeyNavigation.backtab: upTarget
                onClicked: root.bluetooth.activate(device)
                onEnsureVisible: item => root.reveal(item)
                verticalPadding: Metrics.space4
                contentItem: UI.IconLabel {
                    text: entry.text
                    trailingIcon: entry.device && entry.device.connected ? "check" : ""
                    font: entry.font; color: entry.foreground
                    horizontalAlignment: Text.AlignLeft
                }
            }
            onItemAdded: root.navigationRevision++
            onItemRemoved: (_index, item) => {
                root.navigationRevision++;
                if (item === root.lastFocused) recover.restart();
            }
        }
        UI.PanelText {
            objectName: "bluetoothEmpty"
            width: parent.width
            visible: !!root.bluetooth.adapter && devices.count === 0
            text: qsTr("Brak urządzeń")
            color: Theme.textMuted
        }
        UI.NavigationButton {
            id: manager
            objectName: "bluetoothManager"
            width: parent.width
            text: root.bluetooth.backend.managerBusy ? qsTr("Otwieranie menedżera…") : qsTr("Sparuj urządzenie…")
            tooltip: qsTr("Otwórz Blueman w osobnym oknie, aby sparować nowe urządzenie")
            upTarget: root.lastDevice()
            downTarget: root.nextControl
            KeyNavigation.tab: root.nextControl
            KeyNavigation.backtab: upTarget
            onClicked: root.bluetooth.openManager()
            onEnsureVisible: item => root.reveal(item)
        }
    }
    Timer {
        id: recover
        interval: 0
        onTriggered: {
            if (!root.enabled || !root.visible) return;
            const current = root.Window.window ? root.Window.window.activeFocusItem : null;
            if (!current || !current.enabled || !current.visible || !current.activeFocusOnTab)
                expand.forceActiveFocus(Qt.TabFocusReason);
        }
    }
    Connections {
        target: root.bluetooth
        function onCanRequestChanged(): void { recover.restart(); }
        function onRadioEnabledChanged(): void { recover.restart(); }
    }
    Connections {
        target: root.bluetooth.backend
        function onManagerRequested(): void { root.handoffRequested(); }
    }
}
