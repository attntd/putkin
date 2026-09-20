pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../core/Icons.js" as Icons
import "../../components" as UI

Column {
    id: root
    property var audio: null
    property var brightness: null
    property var nightLight: null
    property var caffeinate: null
    property var battery: null
    property var network: null
    property var bluetooth: null
    property var notifications: null
    property var sessionService: null
    property var notificationController: null
    property string monitor: ""
    readonly property AudioSection audioSection: audioLoader.item as AudioSection
    readonly property BrightnessSection brightnessSection: brightnessLoader.item as BrightnessSection
    readonly property NightLightSection nightLightSection: nightLightLoader.item as NightLightSection
    readonly property Item firstControl: audioSection ? audioSection.firstControl : afterAudio
    readonly property Item afterAudio: brightnessSection ? brightnessSection.firstControl : afterBrightness
    readonly property var tiles: [wifi, bluetoothTile, dnd, nightToggle, coffee].filter(tile => tile.visible)
    property bool caffeinateExpanded: false
    property var modeControls: []
    readonly property Item firstTile: tiles.find(tile => tile.enabled) || afterTiles
    readonly property Item lastTile: tiles.slice().reverse().find(tile => tile.enabled) || beforeTiles
    readonly property Item beforeTiles: brightnessSection ? brightnessSection.lastControl : audioSection ? audioSection.lastControl : settings
    readonly property Item afterBrightness: firstTile
    readonly property Item afterModes: nightLightSection && nightLightSection.shown && nightLightSection.firstControl.enabled ? nightLightSection.firstControl : footerFirst
    readonly property Item afterTiles: caffeinateExpanded && modeControls.length ? modeControls[0] : afterModes
    readonly property Item beforeBrightness: audioSection ? audioSection.lastControl : settings
    readonly property Item beforeFooter: afterModes !== footerFirst ? afterModes : caffeinateExpanded && modeControls.length ? modeControls[modeControls.length - 1] : lastTile
    readonly property Item footerFirst: lock.visible && lock.enabled ? lock : settings
    property var focusedControl: null
    property int focusedReason: Qt.TabFocusReason
    spacing: Metrics.space12
    signal requested(string surface)
    signal dismissed()
    signal handoffRequested()
    signal ensureVisible(Item item)
    function rebuildModeNavigation(): void {
        // itemAt() alone does not notify bindings as asynchronous delegates arrive.
        const items = [];
        for (let i = 0; i < modeButtons.count; ++i) items.push(modeButtons.itemAt(i));
        modeControls = items;
    }
    function focusInitial(reason = Qt.TabFocusReason): void { firstControl.forceActiveFocus(reason); }
    function sections(): var { return [audioSection, brightnessSection].filter(section => section !== null); }
    function selectSection(selected: var): void {
        if (!selected.expanded) return;
        caffeinateExpanded = false;
        sections().forEach(section => { if (section !== selected) section.expanded = false; });
    }
    function dismissOrCollapse(): void {
        if (caffeinateExpanded) { caffeinateExpanded = false; coffee.forceActiveFocus(Qt.TabFocusReason); return; }
        const open = sections().find(section => section.expanded);
        if (open) open.collapse(); else dismissed();
    }
    function toggleCaffeinateModes(): void {
        caffeinateExpanded = !caffeinateExpanded;
        if (caffeinateExpanded) {
            sections().forEach(section => section.expanded = false);
            Qt.callLater(() => root.ensureVisible(coffee));
        }
    }
    function reveal(item: Item): void { focusedControl = item; rememberReason(); ensureVisible(item); }
    function rememberReason(): void {
        const reason = focusedControl ? focusedControl.focusReason : Qt.OtherFocusReason;
        if ([Qt.MouseFocusReason, Qt.TabFocusReason, Qt.BacktabFocusReason, Qt.ShortcutFocusReason].indexOf(reason) >= 0)
            focusedReason = reason;
    }
    function recoverFocus(): void {
        if (!focusedControl || (focusedControl.activeFocus && focusedControl.enabled && focusedControl.visible)) return;
        // Audio and brightness own their own fallback controls. A Night Light
        // refresh must not override their repair when both services disappear.
        if (!focusedControl.objectName.startsWith("caffeinate") && !focusedControl.objectName.startsWith("nightLight")) return;
        if (focusedControl.enabled && focusedControl.visible) {
            focusedControl.forceActiveFocus(focusedReason);
            return;
        }
        const target = focusedControl.objectName.startsWith("caffeinate") ? coffee : nightToggle;
        (target.enabled ? target : firstTile).forceActiveFocus(focusedReason);
    }
    function gridTarget(tile: Item, dx: int, dy: int): Item {
        const index = tiles.indexOf(tile);
        if (index < 0) return dy < 0 ? beforeTiles : afterTiles;
        if (dx && (index % 2 + dx < 0 || index % 2 + dx > 1)) return null;
        const next = index + dx + dy * 2;
        return next < 0 ? beforeTiles : next >= tiles.length ? (dy ? afterTiles : null) : tiles[next];
    }
    function tabTarget(tile: Item, step: int): Item {
        let next = tiles.indexOf(tile) + step;
        while (next >= 0 && next < tiles.length) {
            if (tiles[next].enabled) return tiles[next];
            next += step;
        }
        return step < 0 ? beforeTiles : afterTiles;
    }
    component Toggle: UI.ToggleTile {
        id: tile
        width: (tilesGrid.width - tilesGrid.columnSpacing) / 2
        leftTarget: root.gridTarget(tile, -1, 0); rightTarget: root.gridTarget(tile, 1, 0)
        upTarget: root.gridTarget(tile, 0, -1); downTarget: root.gridTarget(tile, 0, 1)
        KeyNavigation.tab: root.tabTarget(tile, 1); KeyNavigation.backtab: root.tabTarget(tile, -1)
        onEnsureVisible: item => root.reveal(item)
    }
    Loader {
        id: audioLoader
        width: parent.width
        active: root.audio !== null
        visible: active
        sourceComponent: AudioSection {
            audio: root.audio; monitor: root.monitor
            previousControl: settings; nextControl: root.afterAudio
            onExpandedChanged: root.selectSection(this)
            onEnsureVisible: item => root.reveal(item)
        }
    }
    Loader {
        id: brightnessLoader
        width: parent.width
        active: root.brightness !== null
        visible: active
        sourceComponent: BrightnessSection {
            brightness: root.brightness; monitor: root.monitor
            previousControl: root.beforeBrightness; nextControl: root.afterBrightness
            onExpandedChanged: root.selectSection(this)
            onEnsureVisible: item => root.reveal(item)
        }
    }
    Grid {
        id: tilesGrid
        width: parent.width
        columns: 2
        columnSpacing: Metrics.space12
        rowSpacing: Metrics.space12
        visible: root.network !== null || root.bluetooth !== null || root.notifications !== null || root.nightLight !== null || root.caffeinate !== null
        Toggle {
            id: wifi
            objectName: "wifiRadio"
            visible: root.network !== null
            text: qsTr("Wi-Fi"); symbol: Icons.network(root.network, false)
            checked: root.network !== null && root.network.wifiEnabled
            enabled: root.network !== null && root.network.available && root.network.wifiDevices.length > 0
                && root.network.hardwareEnabled && !root.network.radioBusy
            onClicked: root.network.setWifiEnabled(!root.network.wifiEnabled)
        }
        Toggle {
            id: bluetoothTile
            objectName: "bluetoothRadio"
            visible: root.bluetooth !== null
            text: qsTr("Bluetooth"); symbol: "bluetooth"
            checked: root.bluetooth !== null && root.bluetooth.radioEnabled
            enabled: root.bluetooth !== null && root.bluetooth.canRequest && !root.bluetooth.blocked
            onClicked: root.bluetooth.setEnabled(!root.bluetooth.radioEnabled)
        }
        Toggle {
            id: dnd
            objectName: "notificationDnd"
            visible: root.notifications !== null
            text: qsTr("Nie przeszkadzać"); symbol: "notifications_off"
            checked: root.notifications !== null && root.notifications.dnd
            enabled: root.notifications !== null && root.notifications.available
            onClicked: root.notifications.dnd = !root.notifications.dnd
        }
        Toggle {
            id: nightToggle
            objectName: "nightLightToggle"
            visible: root.nightLight !== null
            text: qsTr("Światło nocne"); symbol: "bedtime"
            checked: root.nightLight !== null && root.nightLight.enabled
            enabled: root.nightLight !== null && root.nightLight.available && !root.nightLight.busy
            onClicked: root.nightLight.setEnabled(!root.nightLight.enabled)
        }
        Toggle {
            id: coffee
            objectName: "caffeinateToggle"
            visible: root.caffeinate !== null
            text: "Caffeinate"; symbol: "coffee"
            checked: root.caffeinate !== null && root.caffeinate.enabled
            enabled: root.caffeinate !== null && root.caffeinate.available && !root.caffeinate.busy
            hasDetails: true
            onClicked: root.caffeinate.setEnabled(!root.caffeinate.enabled)
            onDetailsRequested: root.toggleCaffeinateModes()
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    coffee.forceActiveFocus(Qt.MouseFocusReason);
                    coffee.focusReason = Qt.MouseFocusReason;
                    root.toggleCaffeinateModes();
                }
            }
        }
    }
    UI.FadeColumn {
        width: parent.width
        shown: root.caffeinateExpanded
        spacing: Metrics.space4
        Repeater {
            id: modeButtons
            model: root.caffeinate ? root.caffeinate.modes : []
            onItemAdded: root.rebuildModeNavigation()
            onItemRemoved: root.rebuildModeNavigation()
            UI.NavigationButton {
                required property var modelData
                required property int index
                objectName: "caffeinateMode-" + modelData.id
                width: parent.width
                text: modelData.label
                highlighted: root.caffeinate.mode === modelData.id
                enabled: root.caffeinate.available && !root.caffeinate.busy
                upTarget: index > 0 ? root.modeControls[index - 1] || null : coffee
                downTarget: index + 1 < root.modeControls.length ? root.modeControls[index + 1] || null : root.afterModes
                KeyNavigation.tab: downTarget; KeyNavigation.backtab: upTarget
                onClicked: {
                    const reason = focusReason;
                    root.caffeinate.setMode(modelData.id);
                    root.caffeinateExpanded = false;
                    root.focusedControl = coffee;
                    root.focusedReason = reason;
                    if (coffee.enabled) coffee.forceActiveFocus(reason);
                }
                onEnsureVisible: item => root.reveal(item)
            }
        }
    }
    Loader {
        id: nightLightLoader
        width: parent.width
        active: root.nightLight !== null
        visible: active && root.nightLightSection && (root.nightLightSection.shown || root.nightLightSection.opacity > 0)
        sourceComponent: NightLightSection {
            nightLight: root.nightLight
            previousControl: root.caffeinateExpanded && root.modeControls.length ? root.modeControls[root.modeControls.length - 1] : root.lastTile
            nextControl: root.footerFirst
            onEnsureVisible: item => root.reveal(item)
        }
    }
    Connections {
        target: root.focusedControl
        function onFocusReasonChanged(): void { root.rememberReason(); }
    }
    Connections {
        target: root.nightLight
        function onRefreshed(): void { Qt.callLater(root.recoverFocus); }
    }
    Connections {
        target: root.caffeinate
        function onBusyChanged(): void { if (!root.caffeinate.busy) Qt.callLater(root.recoverFocus); }
    }
    Row {
        width: parent.width
        spacing: Metrics.space12
        UI.ActionTile {
            id: lock
            objectName: "lockButton"
            visible: root.sessionService !== null
            width: (parent.width - parent.spacing * 2) / 3
            text: qsTr("Blokada"); symbol: "lock"
            enabled: root.sessionService !== null && !root.sessionService.busy && root.sessionService.capability("lock").available
            upTarget: root.beforeFooter; rightTarget: settings
            KeyNavigation.tab: settings; KeyNavigation.backtab: upTarget
            onClicked: root.sessionService.request("lock")
            onEnsureVisible: item => root.reveal(item)
        }
        UI.ActionTile {
            id: settings
            objectName: "settingsButton"
            width: root.sessionService ? lock.width : parent.width
            text: qsTr("Ustawienia"); symbol: "settings"
            upTarget: root.beforeFooter; leftTarget: lock; rightTarget: power
            KeyNavigation.tab: power.visible ? power : root.firstControl
            KeyNavigation.backtab: lock.enabled && lock.visible ? lock : upTarget
            onClicked: root.requested("settings")
            onEnsureVisible: item => root.reveal(item)
        }
        UI.ActionTile {
            id: power
            objectName: "powerButton"
            visible: root.sessionService !== null
            width: lock.width
            text: qsTr("Zasilanie"); symbol: "power_settings_new"
            upTarget: root.beforeFooter; leftTarget: settings
            KeyNavigation.tab: root.firstControl; KeyNavigation.backtab: settings
            onClicked: root.requested("power")
            onEnsureVisible: item => root.reveal(item)
        }
    }
}
