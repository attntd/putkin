pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../core/Icons.js" as Icons
import "../../components" as UI
import "../tray"

Rectangle {
    id: root
    readonly property bool accentScope: true
    readonly property real contentHeight: Math.max(0, height - Metrics.borderWidth)
    required property var service
    required property string screenName
    required property date date
    property var audio: null
    property var battery: null
    property var tray: null
    property var network: null
    property var bluetooth: null
    property var notifications: null
    property string activeModule: ""
    property bool navigating: false
    property bool panelActive: false
    property bool batteryPanelActive: false
    property bool audioPanelActive: false
    property bool windowedTooltips: false
    readonly property alias workspaces: strip
    readonly property alias clock: clock
    readonly property alias quickSettingsButton: quickSettings
    readonly property alias audioButton: audioButton
    readonly property alias batteryButton: batteryButton
    readonly property alias networkButton: networkButton
    readonly property alias bluetoothButton: bluetoothButton
    readonly property alias notificationsButton: notificationsButton
    readonly property alias trayStrip: trayStrip
    signal trayMenuRequested(var item, Item invoker)
    signal trayOverflowRequested(Item invoker)
    signal trayActivationRequested(var item, bool secondary)
    signal dismissed()
    signal quickSettingsRequested(Item invoker)
    signal batteryRequested(Item invoker)
    signal audioRequested(Item invoker)
    signal moduleRequested(string surface, Item invoker)

    function focusQuickSettings(): void { quickSettings.focusReason = Qt.TabFocusReason; quickSettings.forceActiveFocus(Qt.TabFocusReason); }
    function enter(): void { if (strip.available) strip.enter(); else focusQuickSettings(); }
    readonly property Item firstStatus: trayStrip.width > 0 ? trayStrip.firstControl : networkButton.visible ? networkButton
        : bluetoothButton.visible ? bluetoothButton : audioButton.visible ? audioButton : batteryButton.visible ? batteryButton : notificationsButton.visible ? notificationsButton : quickSettings
    implicitHeight: Metrics.barHeight
    color: Theme.background
    Keys.priority: Keys.AfterItem
    Keys.onPressed: event => {
        if (DismissKeys.matches(event, root)) {
            root.dismissed();
            event.accepted = true;
        }
    }

    WorkspaceStrip {
        id: strip
        width: Math.min(Metrics.workspaceMaxWidth, Math.max(Metrics.workspaceWidth, root.width - status.width - Metrics.space8))
        height: root.contentHeight
        service: root.service
        screenName: root.screenName
        navigating: root.navigating
        nextControl: root.firstStatus
        visible: available
        onDismissed: root.dismissed()
    }
    Row {
        id: status
        anchors.right: parent.right
        height: root.contentHeight
        TrayStrip {
            id: trayStrip
            height: parent.height
            tray: root.tray
            capacity: root.width >= 1000 ? Metrics.trayVisibleLimit : root.width >= 600 ? 2 : 0
            previousControl: strip.available ? strip.list.currentItem : quickSettings
            nextControl: networkButton.visible ? networkButton : bluetoothButton.visible ? bluetoothButton : audioButton.visible ? audioButton : batteryButton.visible ? batteryButton : notificationsButton.visible ? notificationsButton : quickSettings
            onMenuRequested: (item, invoker) => root.trayMenuRequested(item, invoker)
            onOverflowRequested: invoker => root.trayOverflowRequested(invoker)
            onActivationRequested: (item, secondary) => root.trayActivationRequested(item, secondary)
            onDismissed: root.dismissed()
        }
        StatusButton {
            id: networkButton
            objectName: "barNetwork"
            visible: root.network !== null && root.width >= 480
            highlighted: root.activeModule === "network"
            symbol: Icons.network(root.network, true)
            text: root.network ? root.network.statusText : ""
            leftTarget: trayStrip.width > 0 ? trayStrip.lastControl : strip.available ? strip.list.currentItem : null
            rightTarget: bluetoothButton.visible ? bluetoothButton : audioButton.visible ? audioButton : batteryButton.visible ? batteryButton : notificationsButton.visible ? notificationsButton : quickSettings
        }
        StatusButton {
            id: bluetoothButton
            objectName: "barBluetooth"
            visible: root.bluetooth !== null && root.bluetooth.adapter !== null && root.width >= 600
            highlighted: root.activeModule === "bluetooth"
            symbol: root.bluetooth && root.bluetooth.radioEnabled ? "bluetooth" : "bluetooth_disabled"
            text: root.bluetooth ? root.bluetooth.statusText : ""
            leftTarget: networkButton.visible ? networkButton : trayStrip.width > 0 ? trayStrip.lastControl : strip.available ? strip.list.currentItem : null
            rightTarget: audioButton.visible ? audioButton : batteryButton.visible ? batteryButton : notificationsButton.visible ? notificationsButton : quickSettings
        }
        StatusButton {
            id: audioButton
            objectName: "barAudio"
            visible: root.audio !== null && (root.width >= 480 || (!batteryButton.visible && trayStrip.width === 0))
            symbol: root.audio && root.audio.muted ? "volume_off" : "volume_up"
            text: root.audio ? qsTr("Dźwięk · ") + root.audio.statusText : ""
            highlighted: root.audioPanelActive
            leftTarget: bluetoothButton.visible ? bluetoothButton : networkButton.visible ? networkButton : trayStrip.width > 0 ? trayStrip.lastControl : strip.available ? strip.list.currentItem : null
            rightTarget: batteryButton.visible ? batteryButton : notificationsButton.visible ? notificationsButton : quickSettings
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (root.audio && root.audio.available && wheel.angleDelta.y !== 0) {
                        root.audio.changeVolume(wheel.angleDelta.y > 0 ? 5 : -5, root.screenName);
                        wheel.accepted = true;
                    } else wheel.accepted = false;
                }
            }
        }
        BatteryButton {
            id: batteryButton
            height: parent.height
            objectName: "barBattery"
            battery: root.battery
            visible: root.battery !== null && root.battery.present
            width: visible ? implicitWidth : 0
            leftTarget: audioButton.visible ? audioButton : bluetoothButton.visible ? bluetoothButton : networkButton.visible ? networkButton : trayStrip.width > 0 ? trayStrip.lastControl : strip.available ? strip.list.currentItem : null
            rightTarget: notificationsButton.visible ? notificationsButton : quickSettings
            KeyNavigation.backtab: leftTarget
            KeyNavigation.tab: rightTarget
            highlighted: root.batteryPanelActive
            onClicked: root.batteryRequested(batteryButton)
            Keys.onEscapePressed: root.dismissed()
            onVisibleChanged: { if (!visible && activeFocus) root.focusQuickSettings(); }
        }
        StatusButton {
            id: notificationsButton
            objectName: "barNotifications"
            visible: root.notifications !== null
            symbol: Icons.notifications(root.notifications)
            text: qsTr("Powiadomienia")
            highlighted: root.activeModule === "notifications"
            leftTarget: batteryButton.visible ? batteryButton : audioButton.visible ? audioButton : bluetoothButton.visible ? bluetoothButton : networkButton.visible ? networkButton : trayStrip.width > 0 ? trayStrip.lastControl : strip.available ? strip.list.currentItem : null
            rightTarget: quickSettings
        }
        StatusButton {
            id: quickSettings
            objectName: "quickSettingsButton"
            symbol: "tune"
            text: qsTr("Szybkie ustawienia")
            highlighted: root.panelActive
            leftTarget: notificationsButton.visible ? notificationsButton : batteryButton.visible ? batteryButton : audioButton.visible ? audioButton : bluetoothButton.visible ? bluetoothButton : networkButton.visible ? networkButton : trayStrip.width > 0 ? trayStrip.lastControl : strip.available ? strip.list.currentItem : null
            KeyNavigation.tab: strip.available ? strip.list.currentItem : quickSettings
        }
        Clock {
            id: clock
            height: parent.height
            date: root.date
            dateStyle: root.width >= 1500 ? 2 : root.width >= 600 ? 1 : 0
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Metrics.borderWidth; color: Theme.border }
    component StatusButton: UI.NavigationButton {
        id: button
        property string symbol: ""
        width: visible ? Metrics.barStatusReserve : 0
        height: root.contentHeight
        padding: 0
        foreground: Theme.text
        KeyNavigation.tab: rightTarget
        KeyNavigation.backtab: leftTarget
        onClicked: {
            if (button === audioButton) root.audioRequested(button);
            else if (button === networkButton) root.moduleRequested("network", button);
            else if (button === bluetoothButton) root.moduleRequested("bluetooth", button);
            else if (button === notificationsButton) root.moduleRequested("notifications", button);
            else root.quickSettingsRequested(button);
        }
        Keys.onEscapePressed: root.dismissed()
        onVisibleChanged: { if (!visible && activeFocus) root.focusQuickSettings(); }
        contentItem: UI.Glyph { section: "bar"; symbol: button.symbol; color: button.foreground }
        background: UI.AccentRectangle {
            color: button.highlighted ? Theme.accent : button.hovered ? Theme.surface : Theme.background
            accentFill: button.highlighted
            UI.FocusIndicator {
                control: button
                anchors.margins: Metrics.focusWidth
                border.color: button.highlighted ? button.accentTextColor : Theme.focus
            }
        }
    }
}
