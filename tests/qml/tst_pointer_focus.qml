import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../components" as UI

Item {
    id: scene
    width: 1366; height: 900
    MockAudioBackend { id: audioBackend }
    AudioService { id: audio; backend: audioBackend }
    MockBrightnessBackend { id: brightnessBackend }
    BrightnessService { id: brightness; backend: brightnessBackend }
    MockNetworkBackend { id: networkBackend }
    NetworkService { id: network; backend: networkBackend }
    MockBluetoothBackend { id: bluetoothBackend }
    BluetoothService { id: bluetooth; backend: bluetoothBackend }
    MockCaffeinateBackend { id: caffeinateBackend }
    CaffeinateService { id: caffeinate; backend: caffeinateBackend }
    MockNightLightBackend { id: nightBackend }
    NightLightService { id: night; backend: nightBackend }
    MockBatteryBackend { id: batteryBackend }
    BatteryService { id: battery; backend: batteryBackend }
    MockPowerProfileBackend { id: profileBackend }
    PowerProfileService { id: profiles; backend: profileBackend }
    MockSessionBackend { id: sessionBackend }
    SessionService { id: session; backend: sessionBackend }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notices; backend: notificationBackend; screens: preview.coordinator.screens; monitorService: preview.backend }
    MockTray { id: tray }
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
        audio: audio; brightness: brightness; network: network; bluetooth: bluetooth
        nightLight: night; caffeinate: caffeinate; battery: battery; powerProfiles: profiles; sessionService: session
        notifications: notices; tray: tray; trayMenuComponent: tray.menuComponent
    }
    Component { id: plainButton; UI.Button { text: "Przycisk" } }
    Component { id: navigationButton; UI.NavigationButton { text: "Nawigacja" } }
    Component { id: moduleButton; UI.ModuleButton { text: "Moduł" } }
    Component { id: actionTile; UI.ActionTile { text: "Akcja" } }
    Component { id: iconButton; UI.IconButton { accessibleName: "Ikona"; symbol: "volume_up" } }
    Component { id: slider; UI.Slider { accessibleName: "Poziom"; from: 0; to: 100; value: 50 } }
    Component { id: textField; UI.TextField {} }

    TestCase {
        id: tests
        name: "PointerFocus"
        when: windowShown
        SignalSpy { id: clicks; signalName: "clicked" }

        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            preview.barController.close();
            preview.backend.reset();
            audioBackend.reset(); brightnessBackend.reset(); networkBackend.reset();
            bluetoothBackend.reset(); nightBackend.reset(); caffeinateBackend.reset(); caffeinate.selectedMode = "presentation"; tray.reset(6);
            notices.clear(); notices.dnd = false;
            mouseMove(scene, 100, 800);
            wait(20);
        }
        function cleanup() {
            clicks.target = null;
            preview.coordinator.close(false); preview.osd.hide(); notices.clear();
            tryCompare(preview.panelHost, "loaded", false);
            tryCompare(preview.osdHost, "loaded", false);
        }
        function ring(control) {
            const indicator = findChild(control, "focusIndicator");
            verify(indicator !== null, control.objectName + " must use a shared focus indicator");
            return indicator;
        }
        function noRings(item) {
            if (!item) return;
            if (item.objectName === "focusIndicator") verify(!item.visible, "Unexpected mouse focus ring: " + item.control.objectName);
            for (const child of item.children) noRings(child);
        }
        function control(name) { return findChild(preview.panelHost.window, name); }
        function openWithMouse() {
            mouseClick(preview.bar.quickSettingsButton);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("audioVolume").activeFocus);
            wait(Metrics.panelFade + 20);
            noRings(preview);
        }
        function test_shared_buttons_data() {
            return [
                {tag: "button", component: plainButton}, {tag: "navigation", component: navigationButton},
                {tag: "module", component: moduleButton}, {tag: "tile", component: actionTile},
                {tag: "icon", component: iconButton}
            ];
        }
        function test_shared_buttons(data) {
            const button = createTemporaryObject(data.component, scene, {x: 40, y: 100, width: 180});
            verify(button !== null);
            clicks.target = button; clicks.clear();
            button.forceActiveFocus(Qt.TabFocusReason);
            verify(ring(button).visible);
            mouseClick(button);
            compare(clicks.count, 1); verify(!ring(button).visible);
            keyClick(Qt.Key_Space);
            compare(clicks.count, 2); verify(ring(button).visible);
            mouseClick(button);
            compare(clicks.count, 3); verify(!ring(button).visible);
        }
        function test_slider_and_text_keep_standard_input() {
            const level = createTemporaryObject(slider, scene, {x: 40, y: 100, width: 200});
            mouseClick(level, 150, level.height / 2);
            verify(level.value > 60); verify(!ring(level).visible);
            keyClick(Qt.Key_Left); verify(ring(level).visible);
            mousePress(level, 150, level.height / 2);
            mouseMove(level, 60, level.height / 2);
            mouseRelease(level, 60, level.height / 2);
            verify(level.value < 40); verify(!ring(level).visible);
            const field = createTemporaryObject(textField, scene, {x: 40, y: 160, width: 200});
            mouseClick(field); verify(!ring(field).visible);
            for (const key of [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L]) keyClick(key);
            compare(field.text, "hjkl"); verify(ring(field).visible);
            mouseClick(field); verify(!ring(field).visible);
        }
        function test_bar_data() {
            return [
                {tag: "workspace", name: "workspace-2", surface: ""},
                {tag: "tray", name: "tray-app0", surface: ""},
                {tag: "tray-menu", name: "tray-app1", surface: "trayMenu"},
                {tag: "overflow", name: "trayOverflowButton", surface: "trayOverflow"},
                {tag: "network", name: "barNetwork", surface: "network"},
                {tag: "bluetooth", name: "barBluetooth", surface: "bluetooth"},
                {tag: "audio", name: "barAudio", surface: "audio"},
                {tag: "battery", name: "barBattery", surface: "battery"},
                {tag: "notifications", name: "barNotifications", surface: "notifications"},
                {tag: "quick", name: "quickSettingsButton", surface: "quickSettings"}
            ];
        }
        function test_bar(data) {
            const button = findChild(preview.bar, data.name);
            verify(button && button.visible);
            clicks.target = button; clicks.clear();
            mouseClick(button);
            compare(clicks.count, 1);
            compare(preview.coordinator.activeId, data.surface);
            if (data.surface) {
                tryCompare(preview.panelHost, "loaded", true);
                wait(Metrics.panelFade + 30);
            }
            noRings(preview);
            if (!data.surface) {
                if (data.tag === "workspace") compare(preview.workspaceService.activeId("TEST-1"), 2);
                else compare(tray.items.values[0].activations, 1);
            }
        }
        function test_quick_controls_data() {
            return ["audioMute", "audioOutputs", "brightnessDetails", "wifiRadio",
                "bluetoothRadio", "nightLightToggle", "notificationDnd", "caffeinateToggle"]
                .map(name => ({tag: name, name: name}));
        }
        function test_quick_controls(data) {
            openWithMouse();
            const button = control(data.name);
            verify(button && button.enabled && button.visible, data.name);
            clicks.target = button; clicks.clear();
            mouseClick(button);
            compare(clicks.count, 1);
            wait(30);
            noRings(preview);
        }
        function test_keyboard_entry_and_return_after_mouse() {
            openWithMouse();
            keyClick(Qt.Key_L);
            verify(ring(control("audioRow")).visible);
            keyClick(Qt.Key_J);
            verify(ring(control("brightnessRow")).visible);
            mouseClick(control("audioMute")); noRings(preview);
            keyClick(Qt.Key_Return); verify(ring(control("audioRow")).visible);
            keyClick(Qt.Key_Escape); keyClick(Qt.Key_Escape);
            tryCompare(preview.panelHost, "loaded", false);
            preview.barController.focusBar();
            tryVerify(() => preview.bar.workspaces.list.currentItem.activeFocus);
            verify(ring(preview.bar.workspaces.list.currentItem).visible);
        }
        function test_keyboard_bar_entry_on_clicked_workspace() {
            mouseClick(findChild(preview.bar, "workspace-2"));
            noRings(preview);
            preview.barController.focusBar();
            tryVerify(() => preview.bar.workspaces.list.currentItem.activeFocus);
            tryVerify(() => ring(preview.bar.workspaces.list.currentItem).visible);
            mouseClick(preview.bar.workspaces.list.currentItem);
            noRings(preview);
        }
        function test_wifi_password_and_cancel_keep_mouse_reason() {
            mouseClick(preview.bar.networkButton);
            tryCompare(preview.panelHost, "loaded", true);
            wait(Metrics.panelFade + 20);
            mouseClick(control("wifiNetwork-0-2"));
            tryVerify(() => control("wifiPassword").activeFocus);
            noRings(preview);
            for (const key of [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L]) keyClick(key);
            compare(control("wifiPassword").text, "hjkl");
            verify(ring(control("wifiPassword")).visible);
            preview.panelHost.window.ensureVisible(control("wifiCancel"));
            verify(waitForPolish(scene));
            verify(waitForRendering(control("wifiCancel")));
            clicks.target = control("wifiCancel"); clicks.clear();
            mouseClick(control("wifiCancel"));
            compare(clicks.count, 1);
            tryVerify(() => control("wifiExpand").activeFocus);
            noRings(preview);
        }
        function test_quick_details_mouse_actions() {
            openWithMouse();
            for (const pair of [["audioOutputs", "audioOutput-headphones"], ["brightnessDetails", "brightnessRefresh"]]) {
                mouseClick(control(pair[0]));
                wait(Metrics.panelFade + 20);
                const button = control(pair[1]);
                verify(button && button.visible && button.enabled, pair[1]);
                clicks.target = button; clicks.clear();
                mouseClick(button);
                compare(clicks.count, 1);
                wait(30); noRings(preview);
            }
        }
        function test_notification_entry_from_bar() {
            notices.notifyError("Test", "Przykład");
            openWithMouse();
            preview.coordinator.close(false); tryCompare(preview.panelHost, "loaded", false);
            mouseClick(findChild(preview.bar, "barNotifications"));
            tryCompare(preview.coordinator, "activeId", "notifications");
            tryVerify(() => control("notificationDnd").activeFocus);
            noRings(preview);
            keyClick(Qt.Key_K);
            verify(ring(control("notificationDnd")).visible);
        }
        function test_tray_mouse_buttons_submenu_and_keyboard() {
            const trigger = findChild(preview.bar, "tray-app0");
            mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.MiddleButton);
            compare(tray.items.values[0].secondaryActivations, 1);
            noRings(preview);
            trigger.forceActiveFocus(Qt.TabFocusReason);
            mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.RightButton);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("trayMenuEntry-0") && control("trayMenuEntry-0").activeFocus);
            noRings(preview);
            mouseClick(control("trayMenuEntry-3"));
            tryCompare(preview.panelHost.window.page, "depth", 2);
            wait(20); noRings(preview);
            mouseClick(control("trayBack"));
            tryCompare(preview.panelHost.window.page, "depth", 1);
            wait(20); noRings(preview);
            keyClick(Qt.Key_J);
            verify(ring(findChild(preview.panelHost.window.page.currentLevel, "trayMenuEntry-4")).visible);
            keyClick(Qt.Key_K);
            keyClick(Qt.Key_L);
            tryCompare(preview.panelHost.window.page, "depth", 2);
            tryVerify(() => ring(findChild(preview.panelHost.window.page.currentLevel, "trayMenuEntry-0")).visible);
        }
        function test_mouse_page_changes_and_power_confirmation() {
            openWithMouse();
            mouseClick(control("settingsButton"));
            tryVerify(() => control("backButton") && control("backButton").activeFocus);
            tryCompare(preview.panelHost.window, "opacity", 1);
            verify(waitForPolish(scene));
            noRings(preview);
            mouseClick(control("backButton"));
            tryVerify(() => control("powerButton") !== null);
            tryCompare(preview.panelHost.window, "opacity", 1);
            verify(waitForPolish(scene));
            mouseClick(control("powerButton"));
            tryVerify(() => control("power-reboot") !== null);
            verify(waitForPolish(scene));
            noRings(preview);
            mouseClick(control("power-reboot"));
            tryVerify(() => control("powerCancel").activeFocus);
            noRings(preview);
            keyClick(Qt.Key_L); verify(ring(control("powerConfirm")).visible);
            verify(waitForPolish(scene));
            mouseClick(control("powerCancel"));
            tryVerify(() => control("power-logout").activeFocus);
            noRings(preview);
        }
        function test_mouse_close_does_not_resume_bar_navigation() {
            preview.barController.focusBar();
            preview.bar.focusQuickSettings();
            keyClick(Qt.Key_Return);
            tryCompare(preview.panelHost, "loaded", true);
            control("powerButton").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            tryVerify(() => control("powerClose") !== null);
            tryCompare(preview.panelHost.window, "opacity", 1);
            verify(waitForPolish(scene));
            mouseClick(control("powerClose"));
            tryCompare(preview.panelHost, "loaded", false);
            compare(preview.barController.screenName, "");
            noRings(preview);
        }
    }
}
