pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI
import "../settings"
import "../tray"
import "../power"
import "../launcher"
import "../battery"
import "../audio"
import "../network"
import "../bluetooth"
import "../notifications"

UI.FadeScope {
    id: root
    readonly property bool accentScope: true
    required property var host
    property var focusedControl: null
    property int focusedReason: Qt.TabFocusReason
    readonly property var page: pageLoader.item
    readonly property alias viewport: flick
    readonly property real primaryHeight: Math.min(height, (page ? page.implicitHeight : 0) + Metrics.space12 * 2)
    implicitWidth: host.surfaceExtentWidth
    implicitHeight: Math.max((page ? page.implicitHeight : 0) + Metrics.space12 * 2, host.launcherPreviewSize)
    enabled: host.interactive
    shown: host.interactive
    contentReady: pageLoader.status === Loader.Ready
    contentKey: page

    function focusInitial(): void {
        if (!enabled || !page) return;
        const reason = host.coordinator.session ? host.coordinator.session.focusReason : Qt.TabFocusReason;
        focusedReason = reason;
        page.focusInitial(reason);
        if (focusedControl && focusedControl.activeFocus && focusedControl.focusReason !== undefined)
            focusedControl.focusReason = reason;
    }
    function rememberFocusReason(): void {
        if (!focusedControl || focusedControl.focusReason === undefined) return;
        const reason = focusedControl.focusReason;
        if (reason === Qt.MouseFocusReason || reason === Qt.TabFocusReason
                || reason === Qt.BacktabFocusReason || reason === Qt.ShortcutFocusReason)
            focusedReason = reason;
    }
    function ensureVisible(item: Item): void {
        if (!item || !enabled)
            return;
        focusedControl = item;
        rememberFocusReason();
        const y = item.mapToItem(flick.contentItem, 0, 0).y;
        const margin = Metrics.focusOffset + Metrics.focusWidth;
        const visibleHeight = Math.min(item.height, Math.max(1, flick.height - margin * 2));
        if (y - margin < flick.contentY)
            flick.contentY = Math.max(0, y - margin);
        else if (y + visibleHeight + margin > flick.contentY + flick.height)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), y + visibleHeight + margin - flick.height);
    }
    function revealFocus(): void {
        if (focusedControl && focusedControl.activeFocus)
            ensureVisible(focusedControl);
    }

    onEnabledChanged: {
        if (enabled)
            Qt.callLater(focusInitial);
        else
            focus = false;
    }
    Keys.priority: Keys.AfterItem
    Keys.onEscapePressed: { if (page) page.dismissOrCollapse(); }
    Window.onActiveChanged: {
        if (Window.active && enabled) Qt.callLater(() => {
            if (!root.enabled) return;
            if (root.focusedControl && root.focusedControl.enabled && root.focusedControl.visible) {
                if (root.focusedControl.focusReason !== undefined)
                    root.focusedControl.focusReason = root.focusedReason;
                root.focusedControl.forceActiveFocus(root.focusedReason);
            } else root.focusInitial();
        });
    }
    Connections {
        target: root.focusedControl && root.focusedControl.focusReason !== undefined ? root.focusedControl : null
        function onFocusReasonChanged(): void { root.rememberFocusReason(); }
    }

    UI.AccentRectangle {
        width: root.host.surfaceWidth
        height: root.primaryHeight
        color: Theme.backgroundStrong
        border.color: Theme.accentBorder
        border.width: Metrics.borderWidth
        accentOutline: true
    }
    Controls.ScrollView {
        readonly property real inset: Metrics.space12 - Metrics.focusOffset - Metrics.focusWidth
        x: inset
        y: inset
        width: root.host.surfaceWidth - inset * 2
        height: root.primaryHeight - inset * 2
        contentWidth: availableWidth
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        Flickable {
            id: flick
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: pageLoader.height + (Metrics.focusOffset + Metrics.focusWidth) * 2
            onHeightChanged: Qt.callLater(root.revealFocus)
            onContentHeightChanged: Qt.callLater(root.revealFocus)
            Loader {
                id: pageLoader
                x: Metrics.focusOffset + Metrics.focusWidth
                y: x
                width: Math.max(1, flick.width - x * 2)
                sourceComponent: root.host.surfaceId === "settings" ? settingsPage
                    : root.host.surfaceId === "power" ? powerPage
                    : root.host.surfaceId === "launcher" ? launcherPage
                    : root.host.surfaceId === "battery" ? batteryPage
                    : root.host.surfaceId === "audio" ? audioPage
                    : root.host.surfaceId === "network" ? networkPage
                    : root.host.surfaceId === "bluetooth" ? bluetoothPage
                    : root.host.surfaceId === "notifications" ? notificationsPage
                    : root.host.surfaceId === "trayOverflow" || root.host.surfaceId === "trayMenu" ? trayPage : quickPage
                onLoaded: { root.focusedControl = null; Qt.callLater(root.focusInitial); }
            }
        }
    }
    Component { id: quickPage; QuickSettingsView { caffeinate: root.host.caffeinate; nightLight: root.host.nightLight; sessionService: root.host.sessionService; audio: root.host.audio; brightness: root.host.brightness; battery: root.host.battery; network: root.host.network; bluetooth: root.host.bluetooth; notifications: root.host.notifications; notificationController: root.host.notificationController; onHandoffRequested: root.host.coordinator.close(false); monitor: root.host.screen ? root.host.screen.name : "" } }
    Loader {
        id: previewLoader
        active: root.host.launcherPreviewSize > 0 && root.page !== null
        x: root.host.surfaceWidth + Metrics.panelGap
        width: root.host.launcherPreviewSize
        height: width
        sourceComponent: LauncherPreview { service: root.host.launcher; launcherView: root.page }
    }
    Component { id: launcherPage; LauncherView { service: root.host.launcher; previewControl: previewLoader.item as Item; maximumHeight: Math.max(1, root.host.availableHeight - Metrics.space12 * 2) } }
    Component {
        id: powerPage
        PowerView {
            sessionService: root.host.sessionService
            requestedAction: root.host.coordinator.session ? root.host.coordinator.session.powerAction || "" : ""
        }
    }
    Component { id: batteryPage; BatteryView { battery: root.host.battery; powerProfiles: root.host.powerProfiles } }
    Component { id: audioPage; AudioView { audio: root.host.audio; monitor: root.host.screen ? root.host.screen.name : "" } }
    Component { id: networkPage; NetworkView { network: root.host.network } }
    Component { id: bluetoothPage; BluetoothView { bluetooth: root.host.bluetooth; onHandoffRequested: root.host.coordinator.close(false) } }
    Component { id: notificationsPage; NotificationCenter { service: root.host.notifications } }
    Component { id: settingsPage; SettingsView { settings: root.host.coordinator.settings; maximumHeight: Math.max(1, root.height - Metrics.space12 * 2) } }
    Component { id: trayPage; TrayView { host: root.host } }
    Connections {
        target: pageLoader.item
        function onRequested(surface: string): void { root.host.coordinator.open(surface, root.host.screen, null, root.focusedReason); }
        function onDismissed(): void { root.host.coordinator.close(root.focusedReason !== Qt.MouseFocusReason); }
        function onEnsureVisible(item: Item): void { root.ensureVisible(item); }
    }
}
