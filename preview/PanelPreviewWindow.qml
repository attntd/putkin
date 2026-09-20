import QtQuick
import Quickshell
import "../core"
import "../modules/bar"
import "../services"

FloatingWindow {
    id: root
    readonly property string screenshotPath: Quickshell.env("PUTKIN_SCREENSHOT") || ""
    readonly property string scenario: Quickshell.env("PUTKIN_SCENARIO") || "quickSettings"
    readonly property alias scene: scene
    property var settings: previewSettings
    property var launcher: launcherService
    MockLauncherBackend { id: launcherBackend }
    LauncherService { id: launcherService; backend: launcherBackend; workspaceService: scene.workspaceService }
    property var audio: Quickshell.env("PUTKIN_AUDIO") === "1" ? mockAudio : null
    property var brightness: Quickshell.env("PUTKIN_BRIGHTNESS") === "1" ? mockBrightness : null
    property var nightLight: Quickshell.env("PUTKIN_NIGHT_LIGHT") === "1" ? mockNightLight : null
    MockCaffeinateBackend { id: mockCaffeinateBackend }
    CaffeinateService { id: mockCaffeinate; backend: mockCaffeinateBackend }
    MockNightLightBackend { id: mockNightLightBackend }
    NightLightService { id: mockNightLight; backend: mockNightLightBackend }
    WallpaperService { id: wallpaperService; selection: Quickshell.env("PUTKIN_WALLPAPER") || "" }
    property var battery: Quickshell.env("PUTKIN_STATUS") === "1" ? mockBattery : null
    property var powerProfiles: mockPowerProfiles
    MockPowerProfileBackend { id: mockProfileBackend }
    PowerProfileService { id: mockPowerProfiles; backend: mockProfileBackend }
    property var tray: Quickshell.env("PUTKIN_STATUS") === "1" ? mockTray : null
    property var network: Quickshell.env("PUTKIN_NETWORK") === "1" ? mockNetwork : null
    property var bluetooth: Quickshell.env("PUTKIN_BLUETOOTH") === "1" ? mockBluetooth : null
    property var notifications: Quickshell.env("PUTKIN_NOTIFICATIONS") === "1" ? mockNotifications : null
    property var sessionService: Quickshell.env("PUTKIN_SESSION") === "1" ? mockSession : null
    MockSessionBackend { id: mockSessionBackend }
    SessionService { id: mockSession; backend: mockSessionBackend }
    SessionController { service: root.sessionService; coordinator: scene.coordinator; brightness: root.brightness || mockBrightness }
    MockNotificationBackend { id: mockNotificationBackend }
    NotificationService { id: mockNotifications; backend: mockNotificationBackend; screens: scene.coordinator.screens; monitorService: scene.backend }
    MockBluetoothBackend { id: mockBluetoothBackend }
    BluetoothService { id: mockBluetooth; backend: mockBluetoothBackend }
    MockNetworkBackend { id: mockNetworkBackend }
    NetworkService { id: mockNetwork; backend: mockNetworkBackend }
    property Component trayMenuComponent: mockTray.menuComponent
    MockBatteryBackend { id: mockBatteryBackend }
    BatteryService { id: mockBattery; backend: mockBatteryBackend }
    MockTray { id: mockTray }
    readonly property alias audioBackend: mockAudioBackend
    MockAudioBackend { id: mockAudioBackend }
    AudioService { id: mockAudio; backend: mockAudioBackend }
    MockBrightnessBackend { id: mockBrightnessBackend }
    BrightnessService { id: mockBrightness; backend: mockBrightnessBackend }
    SettingsFile { id: previewFile }
    MockSettingsFile { id: keyboardFile }
    MockKeyboardBackend { id: keyboardBackend }
    KeyboardSettings { id: keyboard; storage: keyboardFile; backend: keyboardBackend }
    Settings { id: previewSettings; storage: previewFile; keyboard: keyboard }
    title: "Putkin — testowy podgląd paneli"
    implicitWidth: Number(Quickshell.env("PUTKIN_PREVIEW_WIDTH")) || 1920
    implicitHeight: Number(Quickshell.env("PUTKIN_PREVIEW_HEIGHT")) || 1080
    color: Theme.backgroundStrong
    visible: true
    SystemClock { id: clock; precision: SystemClock.Minutes; enabled: Quickshell.env("PUTKIN_LIVE_CLOCK") === "1" }
    LazyLoader { id: panelLoader; component: scene.panelComponent }
    LazyLoader { id: osdLoader; component: scene.osdComponent }
    LazyLoader { id: notificationLoader; component: scene.notificationComponent }
    PanelPreviewScene {
        id: scene
        anchors.fill: parent
        panelLoader: panelLoader
        launcher: root.launcher
        osdLoader: osdLoader
        audio: root.audio
        brightness: root.brightness
        nightLight: root.nightLight
        caffeinate: mockCaffeinate
        wallpaper: wallpaperService
        battery: root.battery
        powerProfiles: root.powerProfiles
        tray: root.tray
        network: root.network
        bluetooth: root.bluetooth
        notifications: root.notifications
        sessionService: root.sessionService
        notificationLoader: notificationLoader
        trayMenuComponent: root.trayMenuComponent
        settings: root.settings
        date: clock.enabled ? clock.date : new Date(2026, 8, 16, 22, 57)
        Component.onCompleted: { if (clock.enabled) backend.many(); }
    }
    PanelIpc { coordinator: scene.coordinator }
    BarIpc { controller: scene.barController }
    Timer {
        interval: 50
        running: true
        onTriggered: {
            if (scene.Window.window)
                scene.Window.window.requestActivate();
            if (root.scenario === "validation") {
                scene.backend.many();
                mockTray.reset(40);
                mockAudioBackend.speakers.description = "Głośniki · bardzo długa nazwa urządzenia do odbioru interfejsu";
                mockNetworkBackend.home.name = "Dom · długa nazwa sieci gościnnej hjkl";
                mockBluetoothBackend.headphones.name = "Słuchawki · długa nazwa sparowanego urządzenia";
            }
            if (root.scenario === "bluetoothUnavailable") mockBluetoothBackend.available = false;
            if (root.scenario === "bluetoothNoAdapter") mockBluetoothBackend.adapters = [];
            if (root.scenario === "bluetoothOff") mockBluetoothBackend.internal.enabled = false;
            if (root.scenario === "bluetoothEmpty") mockBluetoothBackend.internal.devices.reset([]);
            if (root.scenario === "bluetoothMultiple") mockBluetoothBackend.adapters = [mockBluetoothBackend.internal, mockBluetoothBackend.usb];
            if (root.scenario === "bluetoothPending") { mockBluetoothBackend.automatic = false; mockBluetooth.activate(mockBluetoothBackend.keyboard); }
            if (root.scenario === "bluetoothManagerMissing") mockBluetooth.openManager();
            if (root.scenario === "batteryLow") mockBatteryBackend.battery.percentage = 0.12;
            if (root.scenario === "networkUnavailable") mockNetworkBackend.available = false;
            if (root.scenario === "networkBlocked") { mockNetworkBackend.hardwareEnabled = false; mockNetworkBackend.connectivity = 1; }
            if (root.scenario === "networkOff") { mockNetworkBackend.wifiEnabled = false; mockNetworkBackend.connectivity = 1; }
            if (root.scenario === "networkEmpty") { mockNetworkBackend.wifi.networks.reset([]); mockNetworkBackend.connectivity = 1; }
            if (root.scenario === "networkPortal") { mockNetworkBackend.connectivity = 2; mockNetworkBackend.ethernet.state = 2; }
            if (root.scenario === "batteryAbsent") mockBatteryBackend.battery.isPresent = false;
            if (root.scenario === "batteryFull") { mockBatteryBackend.battery.state = 4; mockBatteryBackend.battery.percentage = 1; }
            if (root.scenario === "batteryNoTime") mockBatteryBackend.battery.timeToEmpty = 0;
            if (root.scenario === "batteryNoProfiles") mockProfileBackend.available = false;
            if (root.scenario === "batteryCharging") { mockBatteryBackend.battery.state = 1; mockBatteryBackend.battery.timeToFull = 3900; }
            if (root.scenario === "audioPanelNoInput") { mockAudioBackend.input.devices = []; mockAudioBackend.input.defaultDevice = null; }
            if (root.scenario === "audioUnavailable" || root.scenario === "audioPanelUnavailable") mockAudioBackend.ready = false;
            if (root.scenario === "brightnessUnavailable") mockBrightnessBackend.devices = [];
            if (root.scenario === "brightnessDenied") mockBrightnessBackend.writeError = "Permission denied";
            if (root.scenario === "nightLightAbsent") mockNightLightBackend.present = false;
            if (root.scenario === "nightLightOff") mockNightLightBackend.enabled = false;
            if (root.scenario === "nightLightDenied") mockNightLightBackend.failure = "denied";
            if (root.scenario !== "closed" && root.scenario !== "osd" && root.scenario !== "brightnessOsd" && !root.scenario.startsWith("notification"))
                scene.coordinator.open(root.scenario.startsWith("network") ? "network" : root.scenario.startsWith("bluetooth") ? "bluetooth" : root.scenario.startsWith("audioPanel") ? "audio" : root.scenario.startsWith("battery") ? "battery" : root.scenario.startsWith("launcher") ? "launcher" : root.scenario.startsWith("power") ? "power" : root.scenario === "settings" ? "settings" : "quickSettings", scene.firstScreen, null);
            if (root.scenario === "launcherCommands") launcherService.startMode("commands");
            if (root.scenario === "launcherIncomplete") launcherService.edit(":w");
            if (root.scenario === "launcherApps") launcherService.edit(":a ");
            if (root.scenario === "launcherFiles") launcherService.edit(":f Plan");
            if (root.scenario === "launcherClipboard") launcherService.edit(":c ");
            if (root.scenario === "launcherClipboardText" || root.scenario === "launcherClipboardImage") {
                launcherBackend.clipboard = [
                    {id: "9", preview: "Plan na kolejny tydzień", binary: false,
                        fullText: "Plan na kolejny tydzień\n\nPoniedziałek\nPrzegląd projektu i notatek ze spotkania.\n\nWtorek\nDopracowanie widoków aplikacji. Sprawdzenie klawiatury, list oraz podglądu obrazów.\n\nŚroda\nOmówienie zmian z zespołem i przygotowanie następnej wersji."},
                    {id: "8", preview: "[[ binary data 3 KiB png 640x360 ]]", binary: true,
                        image: Qt.resolvedUrl("../tests/fixtures/launcher-preview.png").toString()},
                    {id: "7", preview: "Spotkanie jutro o 10:00", binary: false},
                    {id: "6", preview: "https://quickshell.org", binary: false}
                ];
                if (root.scenario === "launcherClipboardImage") launcherBackend.clipboard = launcherBackend.clipboard.slice(1);
                launcherService.edit(":c ");
            }
            if (root.scenario === "launcherWorkspace") launcherService.edit(":w0");
            if (root.scenario === "launcherMove") launcherService.edit(":mw7");
            if (root.scenario === "powerUnavailable") {
                const caps = Object.assign({}, mockSessionBackend.capabilities);
                caps.suspend = { available: false, reason: "Brak Hypridle 0.1.8 z potwierdzeniem blokady w tej sesji." };
                caps.poweroff = { available: false, reason: "Brak uprawnień." };
                mockSessionBackend.capabilities = caps;
            }
            if (root.scenario === "osd" && root.audio) root.audio.changeVolume(5, "TEST-1");
            if ((root.scenario === "brightnessOsd" || root.scenario === "brightnessDenied") && root.brightness)
                root.brightness.change(5, "TEST-1");
            if (root.scenario === "trayOverflow") scene.coordinator.open("trayOverflow", scene.firstScreen, scene.bar.trayStrip.lastControl);
            if (root.scenario === "trayMenu") scene.coordinator.openTray(root.tray.items.values[0], scene.firstScreen, scene.bar.trayStrip.firstControl);
            if (root.notifications && root.scenario.startsWith("notification")) {
                if (root.scenario === "notificationUnavailable") {
                    mockNotificationBackend.errorText = qsTr("Powiadomienia obsługuje inny serwer. Przełącz go przed ponownym uruchomieniem Putkin.");
                    mockNotificationBackend.available = false;
                } else {
                    mockNotifications.dnd = root.scenario === "notificationDnd" || root.scenario === "notificationCritical";
                    if (root.scenario !== "notificationLong" || root.width > 480)
                        mockNotificationBackend.send({appName: "Pliki", summary: "Pobieranie zakończone", body: "Projekt jest gotowy do otwarcia.", expireTimeout: 0, actions: [["default", "Otwórz folder"], ["open", "Pokaż plik"]]});
                    if (root.scenario === "notificationLong") mockNotificationBackend.send({appName: "<b>Aplikacja hjkl</b>", summary: "Długi tytuł, który pozostaje w granicach monitora — " + "szczegóły ".repeat(20), body: "<b>Tekst nadawcy</b> & hjkl\n" + "Długa treść powiadomienia. ".repeat(240), expireTimeout: 0, image: Qt.resolvedUrl("../tests/fixtures/notification-image.svg").toString(), actions: Array.from({length: 8}, (_, i) => [String(i), "Akcja " + (i + 1)])});
                    if (root.scenario === "notificationCritical") mockNotificationBackend.send({appName: "System", summary: "Wymagana uwaga", body: "Krytyczne powiadomienia pozostają widoczne w trybie Nie przeszkadzać.", urgency: 2});
                    mockNotifications.entries.forEach(entry => entry.receivedAt = new Date(2026, 8, 16, 22, 57).getTime());
                }
                if (root.scenario === "notificationDnd" || root.scenario === "notificationUnavailable") scene.coordinator.open("notifications", scene.firstScreen, null);
            }
            if (root.scenario === "errorToast") mockNotifications.notifyError("Dźwięk", "Nie udało się zmienić głośności.");
            console.info("PUTKIN_PREVIEW_READY");
        }
    }
    Timer {
        interval: 250
        running: root.network !== null && root.bluetooth === null && root.scenario !== "closed"
        onTriggered: {
            const page = scene.panelHost.window ? scene.panelHost.window.page : null;
            if (!page || !page.networkSection) return;
            page.networkSection.expanded = true;
            if (root.scenario === "networkPassword") {
                mockNetworkBackend.secure.name = "<b>Sieć hjkl & goście</b>";
                mockNetwork.activate(mockNetworkBackend.secure);
            }
        }
    }
    Timer {
        interval: 250
        running: root.bluetooth !== null && (root.scenario === "basic" || root.scenario.startsWith("bluetooth"))
        onTriggered: {
            const page = scene.panelHost.window ? scene.panelHost.window.page : null;
            if (!page || !page.bluetoothSection) return;
            page.bluetoothSection.expanded = true;
            (root.scenario === "bluetoothDeviceFocus" ? page.bluetoothSection.firstDevice() : page.bluetoothSection.firstControl).forceActiveFocus(Qt.TabFocusReason);
        }
    }
    Timer {
        interval: 250
        running: root.scenario === "brightnessFocus"
        onTriggered: {
            if (scene.panelHost.window && scene.panelHost.window.page.brightnessSection)
                scene.panelHost.window.page.brightnessSection.firstControl.forceActiveFocus(Qt.TabFocusReason);
        }
    }
    Timer {
        interval: 280
        running: root.notifications !== null && root.scenario.startsWith("notification")
        onTriggered: {
            if (root.scenario === "notificationLong") {
                scene.notificationController.enter();
                Qt.callLater(() => {
                    if (scene.notificationStack && scene.notificationStack.count) scene.notificationStack.cardAt(scene.notificationStack.count - 1).actionAt(7).forceActiveFocus(Qt.TabFocusReason);
                });
            } else if (scene.panelHost.window && scene.coordinator.activeId === "notifications")
                scene.panelHost.window.page.focusInitial();
        }
    }
    Timer {
        interval: 300
        running: root.nightLight !== null && root.scenario.startsWith("nightLight")
        onTriggered: {
            if (scene.panelHost.window && scene.panelHost.window.page.nightLightSection)
                scene.panelHost.window.page.tiles.find(tile => tile.objectName === "nightLightToggle").forceActiveFocus(Qt.TabFocusReason);
        }
    }
    Timer {
        interval: 450
        running: root.screenshotPath.length > 0
        onTriggered: root.takeScreenshot()
    }
    Timer {
        interval: 200
        running: root.scenario === "powerConfirm" || root.scenario === "powerUnavailable" || root.scenario === "sessionActions"
        onTriggered: {
            if (!scene.panelHost.window) return;
            const page = scene.panelHost.window.page;
            if (root.scenario === "powerConfirm") page.choose("poweroff");
            else if (root.scenario === "powerUnavailable") page.children.find(child => child.objectName === "powerClose").forceActiveFocus(Qt.TabFocusReason);
            else {
                for (const row of page.children) {
                    const button = Array.from(row.children).find(child => child.objectName === "powerButton");
                    if (button) { button.forceActiveFocus(Qt.TabFocusReason); break; }
                }
            }
        }
    }
    function takeScreenshot(): void {
            if (!scene.grabToImage(result => {
                if (result.saveToFile(root.screenshotPath))
                    console.info("PUTKIN_SCREENSHOT_SAVED");
                else
                    console.error("PUTKIN_SCREENSHOT_FAILED");
            }))
                console.error("PUTKIN_SCREENSHOT_FAILED");
    }
}
