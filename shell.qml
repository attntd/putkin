//@ pragma Env QS_PIPEWIRE_IMMEDIATE_RECONNECT = 1
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "core"
import "services"
import "modules/bar"
import "modules/quicksettings" as Panels
import "modules/settings"
import "modules/osd"
import "modules/notifications"
import "modules/wallpaper"
import "modules/lock"
import "modules/screenshot"
import "modules/authentication"

ShellRoot {
    PersistentProperties { id: lockState; reloadableId: "putkin-lock-state"; property bool locked: false }
    Binding { target: Quickshell; property: "watchFiles"; value: !lockState.locked }
    SettingsFile { id: settingsFile }
    Settings { id: settings; storage: settingsFile; keyboard: keyboard }
    SettingsFile { id: keyboardFile; path: configHome + "/putkin/keyboard.json" }
    KeyboardBackend { id: keyboardBackend }
    KeyboardSettings { id: keyboard; storage: keyboardFile; backend: keyboardBackend }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    HyprlandAppearanceBackend { id: windowAppearanceBackend }
    WindowAppearanceService { backend: windowAppearanceBackend }
    WallpaperService { id: wallpaperService; selection: Quickshell.env("PUTKIN_WALLPAPER") || "" }
    WallpaperWindows { service: wallpaperService }
    HyprlandService { id: hyprland }
    LauncherBackend { id: launcherBackend }
    LauncherService { id: launcherService; backend: launcherBackend; workspaceService: hyprland; keyboard: keyboard; actions: actions }
    LauncherIpc { coordinator: panels; service: launcherService }
    ScreenshotBackend { id: screenshotBackend }
    ScreenshotService { id: screenshotService; backend: screenshotBackend; screens: Quickshell.screens; blocked: lockService.locked }
    ScreenshotHost { service: screenshotService }
    PipewireBackend { id: pipewire }
    AudioService { id: audioService; backend: pipewire }
    AudioIpc { audio: audioService }
    BrightnessBackend { id: backlight }
    BrightnessService { id: brightnessService; backend: backlight }
    BrightnessIpc { brightness: brightnessService }
    NightLightBackend { id: nightLightBackend }
    NightLightService { id: nightLightService; backend: nightLightBackend }
    CaffeinateBackend { id: caffeinateBackend }
    CaffeinateService { id: caffeinateService; backend: caffeinateBackend }
    CaffeinateIpc { service: caffeinateService }
    PamBackend { id: authentication; fingerprintAvailable: sessionBackend.fingerprintAvailable }
    LockHost { id: lockHost; service: lockService; state: lockState; wallpaper: wallpaperService.source }
    LockService { id: lockService; backend: lockHost; authentication: authentication; hold: sessionBackend.unlockHeld }
    AuthenticationService { id: authorization; blocked: lockService.locked }
    AuthenticationBackend { service: authorization }
    AuthenticationHost { service: authorization; screens: Quickshell.screens; monitorService: hyprland; panels: panels; barFocus: barFocus }
    SessionBackend { id: sessionBackend; lockService: lockService }
    SessionService { id: sessionService; backend: sessionBackend }
    IdleService {
        id: idleService
        brightness: brightnessService; session: sessionService; display: idleBackend
        idleBlocked: sessionBackend.idleInhibited || caffeinateService.mode === "presentation"
        sleepBlocked: sessionBackend.sleepInhibited || caffeinateService.enabled
    }
    IdleBackend { id: idleBackend; service: idleService; bridge: sessionBackend }
    Connections {
        target: lockService
        function onLockedChanged(): void { if (lockService.locked) { panels.close(false); barFocus.close(); } }
    }
    Connections { target: sessionService; function onResumed(): void { idleService.resume(); } }
    SessionIpc { service: sessionService; coordinator: panels; lockService: lockService; idleService: idleService }
    SessionController { service: sessionService; coordinator: panels; brightness: brightnessService }
    UPowerBackend { id: powerBackend }
    BatteryService { id: batteryService; backend: powerBackend }
    PowerProfileBackend { id: profileBackend }
    PowerProfileService { id: powerProfiles; backend: profileBackend }
    TrayService { id: trayService }
    NetworkBackend { id: networkBackend }
    NetworkService { id: networkService; backend: networkBackend }
    BluetoothBackend { id: bluetoothBackend }
    BluetoothService { id: bluetoothService; backend: bluetoothBackend }
    NotificationBackend { id: notificationBackend }
    NotificationService { id: notifications; backend: notificationBackend; screens: Quickshell.screens; monitorService: hyprland }
    ErrorNotifications {
        notifications: notifications
        sources: [
            {source: actions, property: "lastError", title: "Działanie"},
            {source: keyboardBackend, property: "lastError", title: "Klawiatura"},
            {source: launcherService, property: "lastError", title: "Launcher"},
            {source: screenshotService, property: "lastError", title: "Zrzut ekranu"},
            {source: powerProfiles, property: "lastError", title: "Tryb pracy"},
            {source: hyprland, property: "lastError", title: "Workspace"},
            {source: audioService, property: "lastError", title: "Dźwięk"},
            {source: audioService.microphone, property: "lastError", title: "Mikrofon"},
            {source: brightnessService, property: "lastError", title: "Jasność"},
            {source: brightnessService, property: "refreshError", title: "Jasność"},
            {source: nightLightService, property: "lastError", title: "Światło nocne"},
            {source: caffeinateService, property: "lastError", title: "Caffeinate"},
            {source: networkService, property: "lastError", title: "Wi-Fi"},
            {source: networkBackend, property: "lastError", title: "Sieć"},
            {source: networkBackend, property: "editorError", title: "Sieć"},
            {source: bluetoothService, property: "lastError", title: "Bluetooth"},
            {source: bluetoothBackend, property: "lastError", title: "Bluetooth"},
            {source: bluetoothBackend, property: "managerError", title: "Bluetooth"},
            {source: sessionService, property: "lastError", title: "Sesja"},
            {source: sessionBackend, property: "errorText", title: "Sesja"},
            {source: lockService, property: "lastError", title: "Blokada"},
            {source: idleService, property: "lastError", title: "Bezczynność"},
            {source: settings, property: "readProblem", title: "Ustawienia"},
            {source: settings, property: "saveProblem", title: "Ustawienia"},
            {source: settings, property: "conflictProblem", title: "Ustawienia"},
            {source: settings, property: "validationProblem", title: "Kolor"},
            {source: notifications, property: "errorText", title: "Powiadomienia"}
        ]
    }
    NotificationFocus { id: notificationFocus; service: notifications; panels: panels; barFocus: barFocus }
    NotificationIpc { service: notifications; controller: notificationFocus }
    NotificationWindows { service: notifications; controller: notificationFocus; panels: panels }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    BarFocus {
        id: barFocus
        service: hyprland
        screenNames: Quickshell.screens.map(screen => screen.name)
    }
    BarIpc { controller: barFocus }
    PanelCoordinator {
        id: panels
        screens: Quickshell.screens
        monitorService: hyprland
        barFocus: barFocus
        settings: settings
    }
    PanelIpc { coordinator: panels }
    SettingsFocus { coordinator: panels; service: hyprland; processId: Quickshell.processId }
    HyprlandActions { id: windowActions; service: hyprland }
    ActionController {
        id: actions
        coordinator: panels; launcher: launcherService; hyprland: hyprland; windowActions: windowActions
        barFocus: barFocus; notificationFocus: notificationFocus; notifications: notifications
        audio: audioService; brightness: brightnessService; sessionService: sessionService
        screenshot: screenshotService
    }
    ActionIpc { controller: actions }
    PanelHost {
        id: panelHost
        coordinator: panels
        loader: panelLoader
        launcher: launcherService
        audio: audioService
        brightness: brightnessService
        nightLight: nightLightService
        caffeinate: caffeinateService
        battery: batteryService
        powerProfiles: powerProfiles
        tray: trayService
        network: networkService
        bluetooth: bluetoothService
        notifications: notifications
        sessionService: sessionService
        notificationController: notificationFocus
        trayMenuComponent: Component { TrayMenuAdapter {} }
    }
    LazyLoader { id: panelLoader; component: panelHost.surfaceId === "settings" ? settingsWindow : popupWindow }
    Component { id: popupWindow; Panels.InteractivePanelWindow { host: panelHost } }
    Component { id: settingsWindow; SettingsWindow { host: panelHost } }
    OsdService { id: osd; audio: audioService; brightness: brightnessService; screens: Quickshell.screens; monitorService: hyprland; panelHost: panelHost }
    OsdHost { id: osdHost; service: osd; loader: osdLoader }
    LazyLoader { id: osdLoader; OsdWindow { host: osdHost } }
    Variants {
        model: Quickshell.screens
        BarWindow {
            required property ShellScreen modelData
            screen: modelData
            service: hyprland
            controller: barFocus
            panels: panels
            audio: audioService
            battery: batteryService
            tray: trayService
            network: networkService
            bluetooth: bluetoothService
            notifications: notifications
            date: clock.date
        }
    }
}
