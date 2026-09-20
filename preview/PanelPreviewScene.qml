pragma ComponentBehavior: Bound

import QtQuick
import "../core"
import "../services"
import "../modules/bar"
import "../modules/quicksettings"
import "../modules/osd"
import "../modules/notifications"
import "../modules/wallpaper"

Rectangle {
    id: root
    required property var panelLoader
    property var settings: mockSettings
    property var launcher: null
    property var audio: null
    property var brightness: null
    property var nightLight: null
    property var caffeinate: null
    property var wallpaper: null
    property var battery: null
    property var powerProfiles: null
    property var tray: null
    property var network: null
    property var bluetooth: null
    property var notifications: null
    property bool errorNotificationsEnabled: false
    property var sessionService: null
    readonly property alias notificationController: notificationFocus
    property var notificationLoader: itemNotificationLoader
    readonly property var notificationStack: notificationLoader.active ? notificationLoader.item : null
    readonly property bool notificationsVisible: notifications !== null && notifications.visibleOn(firstScreen.name).length > 0 && (panels.screenName !== firstScreen.name || panels.activeId !== "notifications" && notifications.visibleOn(firstScreen.name).some(entry => entry.notification && entry.notification.internal === true))
    property int toastsCreated: 0
    property int toastsDestroyed: 0
    property Component trayMenuComponent: null
    property var osdLoader: itemOsdLoader
    readonly property alias osd: osd
    readonly property alias osdHost: osdHost
    property int osdCreated: 0
    property int osdDestroyed: 0
    ErrorNotifications {
        notifications: root.notifications
        sources: root.errorNotificationsEnabled && root.notifications ? [
            {source: root.launcher, property: "lastError", title: "Launcher"},
            {source: root.powerProfiles, property: "lastError", title: "Tryb pracy"},
            {source: root.audio, property: "lastError", title: "Dźwięk"},
            {source: root.audio ? root.audio.microphone : null, property: "lastError", title: "Mikrofon"},
            {source: root.brightness, property: "lastError", title: "Jasność"},
            {source: root.nightLight, property: "lastError", title: "Światło nocne"},
            {source: root.caffeinate, property: "lastError", title: "Caffeinate"},
            {source: root.network, property: "lastError", title: "Wi-Fi"},
            {source: root.bluetooth, property: "lastError", title: "Bluetooth"},
            {source: root.sessionService, property: "lastError", title: "Sesja"},
            {source: root.settings, property: "validationProblem", title: "Kolor"}
        ] : []
    }
    MockSettingsFile { id: mockSettingsFile }
    MockSettingsFile { id: mockKeyboardFile }
    MockKeyboardBackend { id: mockKeyboardBackend }
    KeyboardSettings { id: mockKeyboard; storage: mockKeyboardFile; backend: mockKeyboardBackend }
    Settings { id: mockSettings; storage: mockSettingsFile; keyboard: mockKeyboard }
    Binding { target: Theme; property: "appearance"; value: root.settings.effective }
    color: Theme.backgroundStrong
    Loader {
        anchors.fill: parent
        active: root.wallpaper !== null && root.wallpaper.enabled
        sourceComponent: WallpaperView { service: root.wallpaper }
    }
    readonly property alias coordinator: panels
    readonly property alias panelHost: host
    readonly property alias bar: bar
    readonly property alias barController: barFocus
    readonly property alias backend: mock
    readonly property alias workspaceService: service
    readonly property alias firstScreen: firstScreen
    readonly property alias secondScreen: secondScreen
    property int createdCount: 0
    property int destroyedCount: 0
    property int outsideClicks: 0
    property int desktopClicks: 0
    property date date: new Date(2026, 8, 16, 22, 57)
    readonly property Component panelComponent: Component {
        PanelSurface {
            parent: root
            host: host
            x: host.surfaceX
            y: host.surfaceY(height)
            width: implicitWidth
            height: Math.min(host.surfaceId === "settings" ? Metrics.settingsHeight : implicitHeight, host.availableHeight)
            Component.onCompleted: root.createdCount++
            Component.onDestruction: root.destroyedCount++
        }
    }
    readonly property Component osdComponent: Component {
        LevelOsd {
            parent: root
            shown: osd.visible
            level: osd.level
            label: osd.label
            symbol: osd.symbol
            fillColor: osd.fillColor
            width: Math.min(Metrics.osdWidth, root.width - Metrics.space24)
            height: Metrics.osdHeight
            x: (root.width - width) / 2
            y: root.height - height - Metrics.space24
            Component.onCompleted: root.osdCreated++
            Component.onDestruction: root.osdDestroyed++
        }
    }
    QtObject {
        id: itemOsdLoader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader {
            active: itemOsdLoader.activeAsync
            asynchronous: true
            sourceComponent: root.osdComponent
        }
    }
    OsdService { id: osd; audio: root.audio; brightness: root.brightness; screens: panels.screens; monitorService: service; panelHost: host }
    OsdHost { id: osdHost; service: osd; loader: root.osdLoader }

    QtObject { id: firstScreen; readonly property string name: "TEST-1"; property int width: root.width; property int height: root.height }
    QtObject { id: secondScreen; readonly property string name: "TEST-2"; property int width: 1366; property int height: 768 }
    MockHyprland { id: mock }
    WorkspaceService { id: service; backend: mock }
    BarFocus { id: barFocus; service: service; screenNames: panels.screens.map(screen => screen.name) }
    PanelCoordinator { id: panels; screens: [firstScreen, secondScreen]; monitorService: service; barFocus: barFocus; settings: root.settings }
    NotificationFocus { id: notificationFocus; service: root.notifications; panels: panels; barFocus: barFocus }
    MouseArea { anchors.fill: parent; onClicked: root.desktopClicks++ }
    BarView {
        id: bar
        width: parent.width
        height: Metrics.barHeight
        service: service
        audio: root.audio
        battery: root.battery
        tray: root.tray
        network: root.network
        bluetooth: root.bluetooth
        notifications: root.notifications
        activeModule: panels.screenName === screenName ? panels.activeId : ""
        screenName: firstScreen.name
        date: root.date
        navigating: barFocus.screenName === screenName
        panelActive: panels.screenName === screenName && (panels.activeId === "quickSettings" || panels.activeId === "settings")
        batteryPanelActive: panels.screenName === screenName && panels.activeId === "battery"
        audioPanelActive: panels.screenName === screenName && panels.activeId === "audio"
        onModuleRequested: (surface, invoker) => panels.toggle(surface, firstScreen, invoker)
        onAudioRequested: invoker => panels.toggle("audio", firstScreen, invoker)
        onBatteryRequested: invoker => panels.toggle("battery", firstScreen, invoker)
        onTrayMenuRequested: (item, invoker) => panels.openTray(item, firstScreen, invoker)
        onTrayOverflowRequested: invoker => panels.toggle("trayOverflow", firstScreen, invoker)
        onTrayActivationRequested: (item, secondary) => {
            panels.close(false); barFocus.close();
            if (secondary) item.secondaryActivate(); else item.activate();
        }
        onDismissed: barFocus.close()
        onQuickSettingsRequested: invoker => panels.toggle("quickSettings", firstScreen, invoker)
    }
    // Explicit substitute for the compositor's focus grab in this mock scene.
    MouseArea {
        objectName: "outsideCatcher"
        anchors.fill: parent
        enabled: host.interactive && host.surfaceId !== "settings"
        acceptedButtons: Qt.AllButtons
        onPressed: { root.outsideClicks++; panels.close(false); }
    }
    PanelHost {
        id: host
        coordinator: panels
        loader: root.panelLoader
        launcher: root.launcher
        audio: root.audio
        brightness: root.brightness
        nightLight: root.nightLight
        caffeinate: root.caffeinate
        battery: root.battery
        powerProfiles: root.powerProfiles
        tray: root.tray
        network: root.network
        bluetooth: root.bluetooth
        notifications: root.notifications
        sessionService: root.sessionService
        notificationController: notificationFocus
        trayMenuComponent: root.trayMenuComponent
    }
    onNotificationsVisibleChanged: {
        if (notificationsVisible) { notificationRelease.stop(); notificationLoader.activeAsync = true; }
        else notificationRelease.restart();
    }
    Timer { id: notificationRelease; interval: Metrics.panelFade; onTriggered: root.notificationLoader.activeAsync = false }
    QtObject {
        id: itemNotificationLoader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader {
            active: itemNotificationLoader.activeAsync
            sourceComponent: root.notificationComponent
        }
    }
    readonly property Component notificationComponent: Component {
        NotificationStack {
            shown: root.notificationsVisible
            parent: root
            service: root.notifications
            controller: notificationFocus
            screenName: firstScreen.name
            x: root.width - width - Metrics.panelGap - (panels.screenName === firstScreen.name && panels.activeId !== "launcher" && root.width >= Metrics.panelWidth + Metrics.toastWidth + Metrics.panelGap * 3 ? Metrics.panelWidth + Metrics.panelGap : 0)
            y: Metrics.barHeight + Metrics.panelGap
            width: Math.min(Metrics.toastWidth, root.width - Metrics.panelGap * 2)
            height: implicitHeight
            availableHeight: Math.max(1, root.height - y - Metrics.panelGap)
            Component.onCompleted: root.toastsCreated++
            Component.onDestruction: root.toastsDestroyed++
        }
    }
    Connections {
        target: barFocus
        function onEntered(name: string): void {
            if (name === firstScreen.name)
                bar.enter();
        }
        function onResumed(name: string, invoker: var): void {
            if (name === firstScreen.name) {
                Qt.callLater(() => {
                    if (bar.navigating) {
                        if (invoker && invoker.enabled && invoker.visible)
                            invoker.forceActiveFocus(Qt.TabFocusReason);
                        else
                            bar.focusQuickSettings();
                    }
                });
            }
        }
    }
}
