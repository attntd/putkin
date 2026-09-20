pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../core/Icons.js" as Icons
import "../../services"
import "../../components" as UI

Column {
    id: root
    required property var network
    required property Item previousControl
    required property Item nextControl
    property bool expanded: false
    readonly property Item firstControl: radio.enabled ? radio : expand
    readonly property Item lastControl: expanded ? editor : expand
    readonly property alias passwordField: password
    readonly property Item afterNetworks: network.needsPassword ? password : cancel.visible ? cancel : check.enabled ? check : editor
    property Item lastFocused: null
    property int navigationRevision: 0
    property int requestFocusReason: Qt.TabFocusReason
    signal ensureVisible(Item item)
    spacing: Metrics.space8

    function reveal(item: Item): void {
        lastFocused = item;
        ensureVisible(item);
    }
    function rowAt(repeater: var, index: int): Item {
        return navigationRevision >= 0 && repeater ? repeater.itemAt(index) : null;
    }
    function collapse(): bool {
        if (network.target) {
            network.cancel();
            password.clear();
            expand.forceActiveFocus(Qt.TabFocusReason);
            return true;
        }
        if (!expanded)
            return false;
        expanded = false;
        expand.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }
    function release(): void {
        password.clear();
        network.cancel();
    }
    function rowBefore(deviceIndex: int): Item {
        for (let i = deviceIndex - 1; i >= 0; --i) {
            const group = groups.itemAt(i) as NetworkGroup;
            if (group && group.rows.count)
                return rowAt(group.rows, group.rows.count - 1);
        }
        return expand;
    }
    function rowAfter(deviceIndex: int): Item {
        for (let i = deviceIndex + 1; i < groups.count; ++i) {
            const group = groups.itemAt(i) as NetworkGroup;
            if (group && group.rows.count)
                return rowAt(group.rows, 0);
        }
        return afterNetworks;
    }
    function submit(): void {
        const value = password.text;
        password.clear();
        network.providePsk(network.target, network.serial, value);
    }
    onExpandedChanged: {
        if (!expanded)
            release();
    }
    onEnabledChanged: {
        if (!enabled)
            release();
    }
    onVisibleChanged: {
        if (!visible)
            release();
    }
    Component.onDestruction: release()
    NetworkScanLease {
        network: root.network
        active: root.expanded && root.enabled && root.visible && root.network.canScan
    }

    UI.ModuleRow {
        width: parent.width
        UI.ModuleButton {
            id: radio
            objectName: "wifiRadio"
            width: 128
            text: qsTr("Wi-Fi")
            symbol: Icons.network(root.network, false)
            foreground: root.network.activeWifi.length > 0 ? accentColor : Theme.textMuted
            enabled: root.network.available && root.network.wifiDevices.length > 0 && !root.network.radioBusy && root.network.hardwareEnabled
            rightTarget: expand
            upTarget: root.previousControl
            downTarget: expand.downTarget
            KeyNavigation.tab: expand
            KeyNavigation.backtab: root.previousControl
            onClicked: root.network.setWifiEnabled(!root.network.wifiEnabled)
            onEnsureVisible: item => root.reveal(item)
        }
        UI.ModuleButton {
            id: expand
            objectName: "wifiExpand"
            width: parent.width - radio.width
            arrow: true
            expanded: root.expanded
            text: root.network.radioBusy || root.network.busy ? qsTr("Łączenie…") : !root.network.available ? "—"
                : !root.network.hardwareEnabled ? qsTr("Blokada") : !root.network.wifiEnabled ? qsTr("Wył.")
                : root.network.activeWifi.length ? root.network.label(root.network.activeWifi[0]) : qsTr("Niepołączono")
            leftTarget: radio.enabled ? radio : null
            upTarget: root.previousControl
            downTarget: root.navigationRevision >= 0 && root.expanded ? root.network.canScan ? root.rowAfter(-1) : editor : root.nextControl
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
        Column {
            width: parent.width
            visible: root.network.canScan
            spacing: Metrics.space8
            Repeater {
                id: groups
                model: root.network.wifiDevices
                delegate: NetworkGroup {}
                onItemAdded: root.navigationRevision++
                onItemRemoved: {
                    root.navigationRevision++;
                    recover.restart();
                }
            }
        }
        UI.PanelText {
            width: parent.width
            visible: root.network.needsPassword
            textFormat: Text.PlainText
            text: qsTr("Hasło · ") + root.network.label(root.network.target)
        }
        UI.TextField {
            id: password
            objectName: "wifiPassword"
            width: parent.width
            visible: root.network.needsPassword
            echoMode: TextInput.Password
            passwordMaskDelay: 0
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            maximumLength: 64
            placeholderText: qsTr("Hasło Wi-Fi")
            Accessible.name: qsTr("Hasło Wi-Fi")
            KeyNavigation.tab: submit
            KeyNavigation.backtab: root.rowBefore(groups.count)
            onAccepted: root.submit()
            onEnsureVisible: item => root.reveal(item)
        }
        UI.NavigationButton {
            id: submit
            objectName: "wifiSubmit"
            width: parent.width
            visible: root.network.needsPassword
            enabled: password.text.length > 0
            text: qsTr("Połącz")
            upTarget: password
            downTarget: cancel
            KeyNavigation.tab: cancel
            KeyNavigation.backtab: password
            onClicked: root.submit()
            onEnsureVisible: item => root.reveal(item)
        }
        UI.NavigationButton {
            id: cancel
            objectName: "wifiCancel"
            width: parent.width
            visible: root.network.target !== null
            text: qsTr("Anuluj łączenie")
            upTarget: password.visible ? password : root.rowBefore(groups.count)
            downTarget: check.enabled ? check : editor
            KeyNavigation.tab: downTarget
            KeyNavigation.backtab: upTarget
            onClicked: {
                const reason = focusReason;
                root.release();
                expand.forceActiveFocus(reason);
            }
            onEnsureVisible: item => root.reveal(item)
        }
        UI.NavigationButton {
            id: check
            objectName: "networkCheck"
            width: parent.width
            text: qsTr("Sprawdź połączenie")
            enabled: root.network.available && root.network.backend.connectivityCheckEnabled
            upTarget: cancel.visible ? cancel : root.network.canScan ? root.rowBefore(groups.count) : expand
            downTarget: editor
            KeyNavigation.tab: editor
            KeyNavigation.backtab: upTarget
            onClicked: root.network.checkInternet()
            onEnsureVisible: item => root.reveal(item)
        }
        UI.NavigationButton {
            id: editor
            objectName: "networkEditor"
            width: parent.width
            text: qsTr("Profile sieci")
            upTarget: check.enabled ? check : cancel.visible ? cancel : root.network.canScan ? root.rowBefore(groups.count) : expand
            downTarget: root.nextControl
            KeyNavigation.tab: root.nextControl
            KeyNavigation.backtab: upTarget
            onClicked: root.network.openEditor()
            onEnsureVisible: item => root.reveal(item)
        }
    }
    component NetworkGroup: Column {
        id: group
        required property var modelData
        required property int index
        readonly property alias rows: networks
        width: root.width
        spacing: Metrics.space4
        UI.PanelText {
            width: root.width
            textFormat: Text.PlainText
            visible: root.network.wifiDevices.length > 1
            text: group.modelData.name + (group.modelData.nmManaged ? "" : qsTr(" · poza kontrolą NM"))
            font.pixelSize: Metrics.smallFontSize
            color: Theme.textMuted
        }
        Repeater {
            id: networks
            model: group.modelData.networks
            UI.NavigationButton {
                id: entry
                required property var modelData
                required property int index
                objectName: "wifiNetwork-" + group.index + "-" + index
                width: root.width
                implicitHeight: Metrics.controlHeight
                enabled: group.modelData.nmManaged
                highlighted: modelData.connected
                readonly property string connectionText: root.network.target === modelData && root.network.busy ? qsTr("W toku…") : modelData.connected ? qsTr("Połączono") : modelData.stateChanging ? qsTr("W toku…") : !root.network.canConnect(modelData) ? qsTr("Edytor zewnętrzny") : modelData.known ? qsTr("Zapisana") : qsTr("Połącz")
                text: root.network.label(modelData)
                tooltip: text + " · " + root.network.securityText(modelData) + " · " + connectionText
                upTarget: networks && index > 0 ? root.rowAt(networks, index - 1) : group ? root.rowBefore(group.index) : null
                downTarget: networks && index + 1 < networks.count ? root.rowAt(networks, index + 1) : group ? root.rowAfter(group.index) : null
                KeyNavigation.tab: downTarget
                KeyNavigation.backtab: upTarget
                onClicked: {
                    root.requestFocusReason = focusReason;
                    password.clear();
                    root.network.activate(modelData);
                }
                onEnsureVisible: item => root.reveal(item)
                verticalPadding: Metrics.space4
                contentItem: UI.IconLabel {
                    text: entry.text
                    leadingIcon: Icons.wifi(entry.modelData.signalStrength)
                    trailingIcon: entry.modelData.connected ? "check" : entry.modelData.stateChanging ? "more_horiz" : ""
                    font: entry.font; color: entry.foreground
                    horizontalAlignment: Text.AlignLeft
                }
            }
            onItemAdded: root.navigationRevision++
            onItemRemoved: (_index, item) => {
                root.navigationRevision++;
                if (item === root.lastFocused)
                    recover.restart();
            }
        }
        UI.PanelText {
            width: root.width
            visible: networks && networks.count === 0
            text: qsTr("Brak sieci")
            color: Theme.textMuted
        }
    }
    Timer {
        id: recover
        interval: 0
        onTriggered: {
            if (!root.enabled || !root.visible)
                return;
            const current = root.Window.window ? root.Window.window.activeFocusItem : null;
            if (!current || !current.enabled || !current.visible || !current.activeFocusOnTab)
                expand.forceActiveFocus(Qt.TabFocusReason);
        }
    }
    Timer {
        id: promptFocus
        interval: 0
        onTriggered: {
            if (password.visible && root.enabled)
                password.forceActiveFocus(root.requestFocusReason);
        }
    }
    Connections {
        target: root.network
        function onNeedsPasswordChanged(): void {
            password.clear();
            if (root.network.needsPassword)
                promptFocus.restart();
            else
                recover.restart();
        }
        function onSerialChanged(): void {
            password.clear();
        }
        function onCanScanChanged(): void {
            password.clear();
            recover.restart();
        }
        function onRadioBusyChanged(): void {
            recover.restart();
        }
    }
}
