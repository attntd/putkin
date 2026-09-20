import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../components" as UI
import "../../modules/bar" as Bar

Item {
    id: scene
    width: 1366; height: 768
    MockAudioBackend { id: audioBackend }
    AudioService { id: sound; backend: audioBackend }
    MockBrightnessBackend { id: lightBackend }
    BrightnessService { id: light; backend: lightBackend }
    MockNetworkBackend { id: networkBackend }
    NetworkService { id: connection; backend: networkBackend }
    MockBluetoothBackend { id: bluetoothBackend }
    BluetoothService { id: bluetoothModel; backend: bluetoothBackend }
    MockNightLightBackend { id: nightBackend }
    NightLightService { id: night; backend: nightBackend }
    MockSessionBackend { id: sessionBackend }
    SessionService { id: session; backend: sessionBackend }
    MockBatteryBackend { id: batteryBackend }
    BatteryService { id: batteryModel; backend: batteryBackend }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notices; backend: notificationBackend; screens: preview.coordinator.screens; monitorService: preview.backend }
    QtObject {
        id: panelLoader
        property bool activeAsync: false
        readonly property bool active: loader.status === Loader.Ready
        readonly property var item: active ? loader.item : null
        readonly property Loader loader: Loader { active: panelLoader.activeAsync; sourceComponent: preview.panelComponent }
    }
    PanelPreviewScene {
        id: preview
        anchors.fill: parent
        panelLoader: panelLoader
        audio: sound; brightness: light; network: connection; bluetooth: bluetoothModel
        nightLight: night; sessionService: session; battery: batteryModel
        notifications: notices; errorNotificationsEnabled: true
    }
    TestCase {
        name: "VisualContract"
        when: windowShown
        function control(name) { return findChild(preview.panelHost.window, name); }
        function open() {
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("audioVolume").activeFocus);
        }
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            preview.osd.hide(); notices.clear();
            tryCompare(preview.panelHost, "loaded", false);
            tryCompare(preview.osdHost, "loaded", false);
            tryCompare(preview, "notificationStack", null);
            preview.settings.cancelEdit();
            preview.settings.storage.external('{"schemaVersion":1,"appearance":{"accent":"#cba6f7","accentSecondary":"#89b4fa","reducedMotion":false}}');
            audioBackend.reset(); networkBackend.reset(); bluetoothBackend.reset();
            sound.lastError = ""; connection.lastError = ""; bluetoothModel.lastError = "";
            notificationBackend.available = true;
            notices.dnd = false;
            scene.width = 1366; scene.height = 768;
            mouseMove(scene, 100, 700);
        }
        function cleanup() {
            preview.coordinator.close(false); preview.osd.hide(); notices.clear();
            tryCompare(preview.panelHost, "loaded", false);
            tryCompare(preview.osdHost, "loaded", false);
            tryCompare(preview, "notificationStack", null);
            preview.settings.cancelEdit();
        }
        function test_compact_layout_font_borders_and_no_hover_popup() {
            open(); wait(Metrics.panelFade + 20);
            const surface = preview.panelHost.window;
            verify(surface.height <= 400, "Collapsed Quick Settings must fit in 400 logical pixels");
            verify(surface.viewport.contentHeight <= surface.viewport.height + 1);
            compare(control("lockButton").y, control("settingsButton").y);
            compare(control("powerButton").height, 72);
            compare(control("settingsButton").font.family, "JetBrainsMono Nerd Font Mono");
            verify(Qt.fontFamilies().indexOf(Theme.fontFamily) >= 0);
            compare(control("settingsButton").background.border.width, 2);
            compare(control("audioMute").mapToItem(surface, 0, 0).y, control("audioVolume").mapToItem(surface, 0, 0).y);
            mouseMove(control("settingsButton"), 20, 20); wait(650);
            compare(control("tooltip"), null);
            compare(control("themeButton"), null);
            compare(control("sessionStatus"), null);
        }
        function test_bar_icons_keep_clock_color_across_states() {
            const clockColor = (findChild(preview.bar.clock, "clockLabel") as Text).color;
            function sameColor() {
                for (const button of [preview.bar.audioButton, preview.bar.networkButton,
                        preview.bar.bluetoothButton, preview.bar.batteryButton,
                        preview.bar.notificationsButton, preview.bar.quickSettingsButton]) {
                    const icon = button.contentItem as UI.Glyph;
                    compare(icon.color, clockColor);
                    compare(icon.iconSize, 20); compare(icon.iconPadding, 6);
                }
            }
            compare(preview.bar.audioButton.width, Metrics.barStatusReserve);
            compare(preview.bar.networkButton.width, Metrics.barStatusReserve);
            compare(preview.bar.bluetoothButton.width, Metrics.barStatusReserve);
            compare(preview.bar.batteryButton.width, Metrics.barStatusReserve);
            compare((preview.bar.audioButton.contentItem as UI.Glyph).symbol, "volume_up");
            compare(findChild(preview.bar, "barAudioValue"), null);
            sameColor();
            bluetoothBackend.headphones.connected = false;
            networkBackend.home.state = 4;
            networkBackend.ethernet.state = 4;
            sameColor();
            bluetoothBackend.internal.enabled = false;
            networkBackend.wifiEnabled = false;
            sound.setMuted(true, "TEST-1");
            notices.dnd = true;
            sameColor();
            audioBackend.ready = false;
            networkBackend.available = false;
            sameColor();
            const active = preview.bar.workspaces.list.itemAtIndex(5) as Bar.WorkspaceButton;
            verify(active !== null);
            compare(active.text, String(active.workspaceId));
        }
        function test_network_wifi_family_and_radio_states() {
            networkBackend.ethernet.state = 4;
            const icon = preview.bar.networkButton.contentItem as UI.Glyph;
            for (const entry of [[0.1, "network_wifi_1_bar"], [0.3, "network_wifi_2_bar"],
                    [0.6, "network_wifi_3_bar"], [0.9, "network_wifi"]]) {
                networkBackend.home.signalStrength = entry[0];
                compare(icon.symbol, entry[1]);
                compare(icon.iconSize, 20); compare(icon.iconPadding, 6);
            }
            networkBackend.home.state = 4;
            compare(icon.symbol, "signal_wifi_0_bar");
            networkBackend.wifiEnabled = false;
            compare(icon.symbol, "signal_wifi_off");
            networkBackend.ethernet.state = 2;
            compare(icon.symbol, "settings_ethernet");
        }
        function test_active_modules_keep_light_icons_data() {
            return [{tag: "wifi", name: "barNetwork"}, {tag: "bluetooth", name: "barBluetooth"},
                {tag: "battery", name: "barBattery"}, {tag: "audio", name: "barAudio"},
                {tag: "notifications", name: "barNotifications"}, {tag: "quickMenu", name: "quickSettingsButton"}];
        }
        function test_surface_fade_geometry_data() {
            return ["quickSettings", "network", "bluetooth", "battery"].map(id => ({tag: id}));
        }
        function test_surface_fade_geometry(data) {
            scene.width = 640; scene.height = 480;
            preview.coordinator.open(data.tag, preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            const panel = preview.panelHost.window;
            let geometry = null, partialFrames = 0;
            const started = Date.now();
            while (panel.opacity < 1 && Date.now() - started < 2000) {
                if (panel.opacity > 0) {
                    const current = [panel.x, panel.y, panel.width, panel.height];
                    if (geometry) compare(current, geometry);
                    else geometry = current;
                    partialFrames++;
                }
                wait(16);
            }
            compare(panel.opacity, 1);
            verify(partialFrames >= 2, "Multiple partially visible frames expected");
            verify(!panel.fadePresentation.preparation.running);
        }
        function test_active_modules_keep_light_icons(data) {
            const button = findChild(preview.bar, data.name);
            mouseClick(button);
            tryCompare(preview.panelHost, "loaded", true);
            const panel = preview.panelHost.window;
            let geometry = null;
            const started = Date.now();
            while (panel.opacity < 1 && Date.now() - started < 2000) {
                if (panel.opacity > 0) {
                    const current = [panel.x, panel.y, panel.width, panel.height];
                    if (geometry) compare(current, geometry, data.tag + " geometry during fade");
                    else geometry = current;
                }
                wait(16);
            }
            tryCompare(preview.panelHost.window, "opacity", 1);
            verify(button.highlighted);
            const icon = button.contentItem as UI.Glyph;
            const clockColor = (findChild(preview.bar.clock, "clockLabel") as Text).color;
            compare(icon.color, clockColor);
            verify(button.background.accentFill);
            verify(!findChild(button, "focusIndicator").visible);
            verify(waitForPolish(scene));
            const painted = grabImage(scene), origin = button.mapToItem(scene, 0, 0);
            let lightInk = 0;
            for (let y = Math.round(origin.y) + 5; y < origin.y + button.height - 5; ++y)
                for (let x = Math.round(origin.x) + 5; x < origin.x + button.width - 5; ++x)
                    if (Math.abs(painted.red(x, y) - 255 * clockColor.r) < 3
                            && Math.abs(painted.green(x, y) - 255 * clockColor.g) < 3
                            && Math.abs(painted.blue(x, y) - 255 * clockColor.b) < 3) ++lightInk;
            verify(lightInk > 4, "Active icon must keep the clock color: " + data.tag);
            mouseClick(button);
            tryCompare(preview.panelHost, "loaded", false);
            verify(!button.highlighted);
            verify(!button.background.accentFill);
        }
        function test_one_detail_section_and_keyboard_entry() {
            open();
            control("audioVolume").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            const page = preview.panelHost.window.page;
            verify(page.audioSection.expanded);
            control("brightnessDetails").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            verify(page.brightnessSection.expanded); verify(!page.audioSection.expanded);
            verify(control("nightLightTemperature").visible);
            verify(control("wifiExpand") === null); verify(control("bluetoothExpand") === null);
            keyClick(Qt.Key_Escape); verify(!page.brightnessSection.expanded);
            verify(control("brightnessDetails").activeFocus);
            verify(control("nightLightTemperature").visible);
        }
        function test_error_is_a_toast_with_panel_open_and_in_dnd() {
            open(); notices.dnd = true;
            audioBackend.rejectWrites = true;
            const height = preview.panelHost.window.height;
            verify(!sound.setVolume(55, "TEST-1"));
            verify(notices.entries.length === 1);
            compare(notices.entries[0].body, sound.lastError);
            tryVerify(() => preview.notificationStack !== null && preview.notificationStack.count === 1);
            compare(preview.coordinator.activeId, "quickSettings");
            compare(preview.panelHost.window.height, height);
            verify(preview.notificationStack.x + preview.notificationStack.width < preview.panelHost.window.x);
            const first = notices.entries[0];
            notices.notifyError("Dźwięk", "Ponowna odmowa");
            compare(notices.entries.length, 1); compare(notices.entries[0], first);
            compare(first.body, "Ponowna odmowa");
            compare(control("audioError"), null);
            notificationBackend.available = false;
            notices.notifyError("Ustawienia", "Nie zapisano pliku");
            compare(notices.entries.length, 2);
        }
        function test_fade_keeps_geometry_and_legacy_motion_cannot_disable_it() {
            open();
            const panel = preview.panelHost.window;
            const geometry = [panel.x, panel.y, panel.width, panel.height];
            tryCompare(panel, "opacity", 1);
            preview.coordinator.close(false);
            wait(35);
            verify(panel.opacity > 0 && panel.opacity < 1);
            compare([panel.x, panel.y, panel.width, panel.height], geometry);
            tryCompare(preview.panelHost, "loaded", false);
            preview.settings.storage.external('{"schemaVersion":1,"appearance":{"reducedMotion":true}}');
            open();
            tryCompare(preview.panelHost.window, "opacity", 1);
            preview.coordinator.close(false);
            compare(panelLoader.activeAsync, true);
            wait(35);
            verify(preview.panelHost.window.opacity > 0 && preview.panelHost.window.opacity < 1);
            tryCompare(panelLoader, "activeAsync", false);
            notices.notifyError("Test", "Błąd");
            tryVerify(() => preview.notificationStack !== null);
            tryCompare(preview.notificationStack.cardAt(0), "opacity", 1);
            tryCompare(preview.notificationStack, "opacity", 1);
            notices.dismiss(notices.entries[0]);
            compare(preview.notificationLoader.activeAsync, true);
            tryCompare(preview.notificationLoader, "activeAsync", false);
        }
        function test_osd_horizontal_and_fade_retains_last_monitor() {
            sound.changeVolume(5, "TEST-1");
            tryCompare(preview.osdHost, "loaded", true);
            const osd = preview.osdHost.window;
            const fill = findChild(osd, "osdFill");
            const value = findChild(osd, "osdValue");
            verify(osd.height <= 56);
            fuzzyCompare(fill.mapToItem(osd, 0, fill.height / 2).y, value.mapToItem(osd, 0, value.height / 2).y, 1);
            tryCompare(osd, "opacity", 1);
            preview.osd.hide();
            compare(preview.osdHost.screen, preview.firstScreen);
            wait(35); verify(osd.opacity > 0 && osd.opacity < 1);
            tryCompare(preview.osdHost, "loaded", false);
            compare(preview.osdHost.screen, null);
        }
    }
}
