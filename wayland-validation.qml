// Only the isolated Wayland test runners may launch this in a private compositor.
// Production windows/controllers, native monitor IPC, explicit domain mocks.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "preview"
import "modules/bar"
import "modules/quicksettings" as Panels
import "modules/osd"
import "modules/notifications"
import "modules/wallpaper"

ShellRoot {
    id: root
    property int created: 0
    property int destroyed: 0
    property var barWindows: []
    property bool fixturesReady: false
    SettingsFile { id: file }
    Settings { id: appearanceSettings; storage: file }
    Binding { target: Theme; property: "appearance"; value: appearanceSettings.effective }
    WallpaperService { id: wallpaper; selection: "solid" }
    WallpaperWindows { service: wallpaper }
    HyprlandService { id: nativeHyprland }
    // Keep a crowded bar while monitor selection and workspace actions use
    // the real private compositor. Only occupancy/urgency are synthetic here.
    WorkspaceService {
        id: hyprland
        backend: QtObject {
            readonly property bool connected: nativeHyprland.available
            readonly property string focusedMonitorName: nativeHyprland.focusedMonitorName
            readonly property var monitors: nativeHyprland.monitors
            readonly property var workspaces: Array.from({length: 30}, (_, i) => ({id: i + 1, occupied: true, urgent: i === 11}))
            function focusMonitor(name: string): void { nativeHyprland.backend.focusMonitor(name); }
            function activateWorkspace(id: int): void { nativeHyprland.backend.activateWorkspace(id); }
        }
    }
    MockAudioBackend { id: audioBackend }
    AudioService { id: audioModel; backend: audioBackend }
    AudioIpc { audio: audioModel }
    MockBrightnessBackend { id: backlight }
    BrightnessService { id: brightnessModel; backend: backlight }
    BrightnessIpc { brightness: brightnessModel }
    MockNightLightBackend { id: nightBackend }
    NightLightService { id: nightModel; backend: nightBackend }
    MockCaffeinateBackend { id: caffeinateBackend }
    CaffeinateService { id: caffeinateModel; backend: caffeinateBackend }
    MockSessionBackend { id: sessionBackend }
    SessionService { id: session; backend: sessionBackend }
    SessionIpc { service: session; coordinator: panelCoordinator }
    SessionController { service: session; coordinator: panelCoordinator; brightness: brightnessModel }
    MockBatteryBackend { id: batteryBackend }
    BatteryService { id: batteryModel; backend: batteryBackend }
    MockTray { id: trayModel }
    MockNetworkBackend { id: networkBackend }
    NetworkService { id: networkModel; backend: networkBackend }
    MockBluetoothBackend { id: bluetoothBackend }
    BluetoothService { id: bluetoothModel; backend: bluetoothBackend }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notificationModel; backend: notificationBackend; screens: Quickshell.screens; monitorService: hyprland }
    NotificationFocus { id: notificationFocus; service: notificationModel; panels: panelCoordinator; barFocus: barController }
    NotificationIpc { service: notificationModel; controller: notificationFocus }
    NotificationWindows { service: notificationModel; controller: notificationFocus; panels: panelCoordinator }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    BarFocus { id: barController; service: hyprland; screenNames: Quickshell.screens.map(screen => screen.name) }
    BarIpc { controller: barController }
    PanelCoordinator { id: panelCoordinator; screens: Quickshell.screens; monitorService: hyprland; barFocus: barController; settings: appearanceSettings }
    PanelIpc { coordinator: panelCoordinator }
    PanelHost {
        id: hostModel
        coordinator: panelCoordinator; loader: panelLoader
        audio: audioModel; brightness: brightnessModel; nightLight: nightModel
        caffeinate: caffeinateModel
        battery: batteryModel; tray: trayModel; network: networkModel; bluetooth: bluetoothModel
        notifications: notificationModel; sessionService: session
        notificationController: notificationFocus; trayMenuComponent: trayModel.menuComponent
    }
    LazyLoader {
        id: panelLoader
        Panels.InteractivePanelWindow {
            host: hostModel
            Component.onCompleted: root.created++
            Component.onDestruction: root.destroyed++
        }
    }
    OsdService { id: osd; audio: audioModel; brightness: brightnessModel; screens: Quickshell.screens; monitorService: hyprland; panelHost: hostModel }
    OsdHost { id: osdHost; service: osd; loader: osdLoader }
    LazyLoader { id: osdLoader; OsdWindow { host: osdHost } }
    Variants {
        model: Quickshell.screens
        BarWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData
            service: hyprland; controller: barController; panels: panelCoordinator
            audio: audioModel; battery: batteryModel; tray: trayModel; network: networkModel; bluetooth: bluetoothModel; notifications: notificationModel; date: clock.date
            Component.onCompleted: root.barWindows = root.barWindows.concat([bar])
            Component.onDestruction: root.barWindows = root.barWindows.filter(window => window !== bar)
        }
    }
    function find(item: var, name: string): var {
        if (!item) return null;
        // A tray submenu retains its hidden parent with identical row names.
        if (item.objectName === name && item.visible) return item;
        for (const child of item.children || []) {
            const result = find(child, name);
            if (result) return result;
        }
        return null;
    }
    function control(name: string): var {
        const panel = hostModel.window;
        const result = panel ? find(panel.contentItem, name) : null;
        if (result) return result;
        for (const bar of barWindows) {
            const item = find(bar.contentItem, name);
            if (item && item.activeFocus) return item;
        }
        return null;
    }
    function focusName(window: var): string {
        const backing = window && window.contentItem.Window.window;
        const item = backing ? backing.activeFocusItem : null;
        return item && item.activeFocus ? item.objectName : "";
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({
                screens: Quickshell.screens.map(s => ({name: s.name, width: s.width, height: s.height})),
                ready: root.fixturesReady && appearanceSettings.ready && hyprland.available, focusedMonitor: hyprland.focusedMonitorName,
                caffeinate: caffeinateModel.mode,
                barScreen: barController.screenName, bars: root.barWindows.map(w => ({screen: w.screen ? w.screen.name : "", focus: root.focusName(w)})),
                loaded: hostModel.loaded, surface: panelCoordinator.activeId, screen: panelCoordinator.screenName,
                focus: root.focusName(hostModel.window), created: root.created, destroyed: root.destroyed,
                editing: appearanceSettings.editing, saving: appearanceSettings.saving, accent: appearanceSettings.effective.accent,
                secondary: appearanceSettings.effective.accentSecondary, persisted: appearanceSettings.persisted.appearance,
                scans: networkBackend.wifi.scanStarts, scanStops: networkBackend.wifi.scanStops, scanning: networkBackend.wifi.scannerEnabled,
                discovery: bluetoothBackend.internal.discovering, sessionCalls: sessionBackend.calls.length,
                volume: audioModel.volume, brightness: brightnessModel.percent, pskCalls: networkBackend.secure.pskCalls,
                needsPassword: networkModel.needsPassword, keyboardConnected: bluetoothBackend.keyboard.connected,
                dnd: notificationModel.dnd, notifications: notificationModel.entries.length, notificationFocus: notificationFocus.screenName,
                osd: osd.visible, osdScreen: osd.screen ? osd.screen.name : "", osdLoaded: osdHost.loaded,
                busy: audioModel.busy || brightnessModel.busy || nightModel.busy,
                brightnessRequests: backlight.requests.length, nightRequests: nightBackend.requests.length,
                menuLeafActivations: trayModel.leaf.activations, trayCount: trayModel.items.values.length
            });
        }
        function control(name: string): string {
            const item = root.control(name);
            if (!item) return "{}";
            const surface = hostModel.window && hostModel.window.contentItem.children.find(child => child["viewport"] !== undefined);
            const point = surface ? item.mapToItem(surface.viewport, 0, 0) : null;
            return JSON.stringify({name: item.objectName, focus: item.activeFocus, enabled: item.enabled, visible: item.visible,
                y: point ? point.y : null, height: item.height, viewportHeight: surface ? surface.viewport.height : null});
        }
        function accentSamples(): string {
            const surface = hostModel.window.contentItem.children.find(child => child["viewport"] !== undefined);
            const samples = [];
            function sample(label, group, originX, originY, x, y) {
                samples.push({label: label, x: Math.round(originX + x), y: Math.round(originY + y),
                    localX: x + .5, localY: y + .5, width: group.width, height: group.height});
            }
            const x = hostModel.surfaceX + surface.x, y = surface.y;
            for (const point of [[1, 1], [surface.width - 2, 1], [1, surface.height - 2], [surface.width - 2, surface.height - 2]])
                sample("frame", surface, x, y, point[0], point[1]);
            for (const name of ["wifiRadio", "bluetoothRadio", "nightLightToggle"]) {
                const tile = root.find(surface, name), point = tile.mapToItem(surface, tile.width - 8, tile.height - 8);
                sample(name, surface, x, y, point.x, point.y);
            }
            const bar = root.barWindows.find(window => window.screen.name === panelCoordinator.screenName);
            const barView = bar.contentItem.children.find(child => child["accentScope"] === true);
            const button = root.find(barView, "quickSettingsButton");
            for (const y of [4, barView.height - 5]) {
                const point = button.mapToItem(barView, 4, y);
                sample("whole-bar", barView, 0, 0, point.x, point.y);
            }
            return JSON.stringify({samples: samples});
        }
        function barGeometry(charging: bool): string {
            batteryBackend.battery.state = charging ? 1 : 2;
            const window = root.barWindows.find(value => value.screen.name === panelCoordinator.screenName);
            const bar = window.contentItem.children.find(child => child["accentScope"] === true);
            function rect(item) {
                const point = item.mapToItem(bar, 0, 0);
                return {x: point.x, y: point.y, width: item.width, height: item.height};
            }
            return JSON.stringify({height: bar.height, contentHeight: bar.contentHeight,
                battery: rect(root.find(bar, "batteryIcon")), clock: rect(root.find(bar, "clock"))});
        }
        function open(id: string): bool { return panelCoordinator.open(id, null, null); }
        function draft(): void { appearanceSettings.setColor("accent", "#abcdef"); }
        function notify(critical: bool): void {
            notificationBackend.send({summary: "Test Waylanda — długa nazwa powiadomienia", body: "Wyłącznie sztuczna treść. <b>Znaczniki</b> pozostają tekstem. ".repeat(4), urgency: critical ? 2 : 1, expireTimeout: 0});
        }
        function clear(): void { notificationModel.clear(); osd.hide(); }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
    Component.onCompleted: Qt.callLater(() => {
        trayModel.reset(40);
        audioBackend.speakers.description = "Głośniki — długa nazwa wyjścia testowego";
        networkBackend.home.name = "Dom — długa nazwa sieci testowej hjkl";
        bluetoothBackend.headphones.name = "Słuchawki — długa nazwa sparowanego urządzenia";
        root.fixturesReady = true;
    })
}
