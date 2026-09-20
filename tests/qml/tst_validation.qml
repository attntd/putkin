import QtQuick
import QtTest
import "../../core"
import "../../core/Appearance.js" as Appearance
import "../../services"
import "../../preview"
import "../../components" as UI

Item {
    id: scene
    width: 1366; height: 768
    MockSettingsFile { id: file }
    Settings { id: settingsModel; storage: file }
    MockAudioBackend { id: audioBackend }
    AudioService { id: audioModel; backend: audioBackend }
    MockBrightnessBackend { id: brightnessBackend }
    BrightnessService { id: brightnessModel; backend: brightnessBackend }
    MockNightLightBackend { id: nightBackend }
    NightLightService { id: nightModel; backend: nightBackend }
    MockBatteryBackend { id: batteryBackend }
    BatteryService { id: batteryModel; backend: batteryBackend }
    MockNetworkBackend { id: networkBackend }
    NetworkService { id: networkModel; backend: networkBackend }
    MockBluetoothBackend { id: bluetoothBackend }
    BluetoothService { id: bluetoothModel; backend: bluetoothBackend }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notificationModel; backend: notificationBackend; screens: preview.coordinator.screens; monitorService: preview.backend }
    MockSessionBackend { id: sessionBackend }
    SessionService { id: sessionModel; backend: sessionBackend }
    MockTray { id: trayModel }
    SessionController { service: sessionModel; coordinator: preview.coordinator; brightness: brightnessModel }
    QtObject {
        id: panelLoader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader {
            active: panelLoader.activeAsync
            asynchronous: true
            sourceComponent: preview.panelComponent
        }
    }
    PanelPreviewScene {
        id: preview
        anchors.fill: parent
        panelLoader: panelLoader
        settings: settingsModel
        audio: audioModel
        brightness: brightnessModel
        nightLight: nightModel
        battery: batteryModel
        network: networkModel
        bluetooth: bluetoothModel
        notifications: notificationModel
        sessionService: sessionModel
        tray: trayModel
        trayMenuComponent: trayModel.menuComponent
    }
    UI.TextField { id: applicationField; y: 100; width: 220; visible: false }

    TestCase {
        name: "ReleaseValidation"
        when: windowShown
        function control(name) { return findChild(preview.panelHost.window, name); }
        function focused(name) { tryVerify(() => control(name) && control(name).activeFocus, 1000, name); }
        function walk(key, name, scope) {
            const parent = scope || preview.panelHost.window;
            const target = findChild(parent, name);
            verify(target !== null, name);
            const trace = [];
            for (let i = 0; i < 50 && !target.activeFocus; ++i) {
                keyClick(key); wait(5);
                trace.push(preview.Window.window.activeFocusItem.objectName);
            }
            verify(target.activeFocus, "Keyboard cannot reach " + name + ": " + trace.join(", "));
        }
        function open() {
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            focused("audioVolume");
        }
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            preview.barController.close();
            preview.osd.hide();
            notificationModel.clear();
            notificationBackend.available = true; notificationModel.dnd = false;
            preview.backend.reset();
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            file.external(Appearance.serialize(Appearance.defaults().appearance));
            file.writes = 0;
            audioBackend.reset(); networkBackend.reset(); bluetoothBackend.reset(); sessionBackend.reset();
            brightnessBackend.reset(); brightnessModel.refresh();
            nightBackend.reset(); nightModel.refresh();
            tryCompare(brightnessModel, "busy", false); tryCompare(nightModel, "busy", false);
            scene.width = 1366; scene.height = 768;
            applicationField.visible = false; applicationField.text = "";
            mouseMove(scene, 100, 600);
        }
        function cleanup() {
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            preview.osd.hide();
            notificationModel.clear();
            applicationField.visible = false;
            verify(!networkBackend.wifi.scannerEnabled);
            compare(sessionBackend.calls.length, 0, "Validation must never request session actions");
        }
        function test_complete_keyboard_journey() {
            preview.barController.focusBar();
            tryVerify(() => preview.bar.workspaces.list.currentItem.activeFocus);
            keyClick(Qt.Key_H); wait(10); keyClick(Qt.Key_Return);
            verify(preview.backend.requests.some(request => request.kind === "activate"));
            compare(preview.barController.screenName, "");
            preview.barController.focusBar();
            tryVerify(() => preview.bar.workspaces.list.currentItem.activeFocus);
            keyClick(Qt.Key_End);
            wait(20);
            walk(Qt.Key_L, "quickSettingsButton", preview.bar);
            keyClick(Qt.Key_Return);
            tryCompare(preview.panelHost, "loaded", true); focused("audioVolume");
            walk(Qt.Key_J, "lockButton"); keyClick(Qt.Key_L); focused("settingsButton"); keyClick(Qt.Key_Return); focused("backButton");
            keyClick(Qt.Key_J); focused("appearanceSection"); keyClick(Qt.Key_J); keyClick(Qt.Key_J); keyClick(Qt.Key_L); keyClick(Qt.Key_L);
            focused("accentPreset5"); keyClick(Qt.Key_Return);
            compare(Theme.accent, "#94e2d5"); compare(file.writes, 0);
            keyClick(Qt.Key_J); focused("accentField"); keyClick(Qt.Key_Return);
            focused("accentSecondaryPreset0"); keyClick(Qt.Key_J); keyClick(Qt.Key_L); keyClick(Qt.Key_Return);
            compare(Theme.accentSecondary, "#fab387");
            keyClick(Qt.Key_J); focused("accentSecondaryField"); keyClick(Qt.Key_Return);
            walk(Qt.Key_J, "saveSettingsButton"); keyClick(Qt.Key_Return);
            tryCompare(settingsModel, "saving", false); compare(file.writes, 1);
            compare(settingsModel.persisted.appearance.accent, "#94e2d5");
            keyClick(Qt.Key_Tab); keyClick(Qt.Key_Tab); focused("appearanceSection"); keyClick(Qt.Key_K); focused("backButton"); keyClick(Qt.Key_Return);
            focused("audioVolume");
            walk(Qt.Key_J, "audioVolume");
            const oldVolume = audioModel.volume;
            keyClick(Qt.Key_L); tryCompare(audioModel, "volume", oldVolume + 5);
            verify(!preview.osd.visible, "Panel suppresses its matching OSD");
            walk(Qt.Key_J, "brightnessSlider");
            const oldBrightness = brightnessModel.percent;
            keyClick(Qt.Key_H); tryCompare(brightnessModel, "percent", oldBrightness - 5);
            keyClick(Qt.Key_Escape);
            walk(Qt.Key_H, "barNetwork", preview.bar); keyClick(Qt.Key_Return);
            focused("wifiRadio"); keyClick(Qt.Key_L); focused("wifiExpand");
            tryCompare(networkBackend.wifi, "scannerEnabled", true);
            walk(Qt.Key_J, "wifiNetwork-0-2"); keyClick(Qt.Key_Return); focused("wifiPassword");
            for (const letter of "hjkl1234") keyClick(letter);
            compare(control("wifiPassword").text, "hjkl1234");
            keyClick(Qt.Key_Return); tryCompare(networkModel, "needsPassword", false);
            compare(networkBackend.secure.pskCalls, 1);
            keyClick(Qt.Key_Escape); verify(!networkBackend.wifi.scannerEnabled);
            walk(Qt.Key_L, "barBluetooth", preview.bar); keyClick(Qt.Key_Return);
            focused("bluetoothRadio"); keyClick(Qt.Key_L);
            walk(Qt.Key_J, "bluetoothDevice-1"); keyClick(Qt.Key_Return);
            tryCompare(bluetoothBackend.keyboard, "connected", true);
            keyClick(Qt.Key_Escape);
            walk(Qt.Key_L, "barNotifications", preview.bar); keyClick(Qt.Key_Return);
            focused("notificationDnd"); keyClick(Qt.Key_Return); verify(notificationModel.dnd);
            notificationBackend.send({summary: "Wyciszone", expireTimeout: 0});
            compare(notificationModel.entries.length, 0);
            notificationBackend.send({summary: "Krytyczne", urgency: 2, expireTimeout: 0});
            compare(notificationModel.entries.length, 1);
            keyClick(Qt.Key_Escape); walk(Qt.Key_L, "quickSettingsButton", preview.bar); keyClick(Qt.Key_Return);
            focused("audioVolume"); walk(Qt.Key_J, "lockButton"); keyClick(Qt.Key_L); keyClick(Qt.Key_L); focused("powerButton"); keyClick(Qt.Key_Return);
            focused("power-logout"); keyClick(Qt.Key_L); keyClick(Qt.Key_Return); focused("powerCancel");
            keyClick(Qt.Key_Return); focused("power-logout"); keyClick(Qt.Key_Escape);
            tryCompare(preview.panelHost, "loaded", false);
            tryVerify(() => preview.bar.quickSettingsButton.activeFocus);
            tryVerify(() => preview.notificationStack !== null);
            verify(preview.bar.quickSettingsButton.activeFocus, "Toast must not steal returned bar focus");
            compare(Theme.accentSecondary, "#fab387");
        }
        function test_passive_overlays_leave_text_input_alone() {
            applicationField.visible = true; applicationField.forceActiveFocus(Qt.TabFocusReason);
            notificationBackend.send({summary: "Neutralny test", body: "Bez prywatnej treści", expireTimeout: 0});
            verify(audioModel.changeVolume(5, "TEST-1"));
            tryVerify(() => preview.osdHost.loaded && preview.notificationStack !== null);
            for (const letter of "hjkl") keyClick(letter);
            compare(applicationField.text, "hjkl"); verify(applicationField.activeFocus);
            compare(preview.barController.screenName, ""); compare(preview.notificationController.screenName, "");
        }
        function test_all_services_unavailable_and_return_in_one_panel() {
            open();
            audioBackend.ready = false; audioBackend.outputs = [];
            networkBackend.available = false; bluetoothBackend.available = false; notificationBackend.available = false;
            brightnessBackend.devices = []; brightnessModel.refresh();
            nightBackend.present = false; nightModel.refresh();
            tryCompare(brightnessModel, "busy", false); tryCompare(nightModel, "busy", false);
            verify(!audioModel.available && !networkModel.available && !bluetoothModel.available);
            verify(!brightnessModel.available && !nightModel.available && !notificationModel.available);
            focused("brightnessDetails");
            walk(Qt.Key_J, "lockButton"); keyClick(Qt.Key_L); focused("settingsButton");
            verify(!networkBackend.wifi.scannerEnabled);
            audioBackend.reset(); networkBackend.reset(); bluetoothBackend.reset(); notificationBackend.available = true;
            brightnessBackend.reset(); brightnessModel.refresh(); nightBackend.reset(); nightModel.refresh();
            tryCompare(brightnessModel, "available", true); tryCompare(nightModel, "available", true);
            verify(audioModel.available && networkModel.available && bluetoothModel.available && notificationModel.available);
            walk(Qt.Key_K, "bluetoothRadio"); keyClick(Qt.Key_H); // Still a usable surface after recovery.
            compare(preview.createdCount - preview.destroyedCount, 1);
        }
        function test_small_logical_screens_data() {
            const data = [];
            for (const size of [[1920,1080], [1366,768]])
                for (const scale of [1,1.25,1.5,2])
                    data.push({tag: size.join("x") + "@" + scale, width: Math.floor(size[0]/scale), height: Math.floor(size[1]/scale)});
            return data;
        }
        function test_small_logical_screens(data) {
            // Geometry only. A Qt Item is not proof of a mixed-scale Wayland output.
            scene.width = data.width; scene.height = data.height;
            trayModel.reset(40); preview.backend.many();
            open();
            const surface = preview.panelHost.window;
            walk(Qt.Key_J, "lockButton"); keyClick(Qt.Key_L); focused("settingsButton");
            const point = control("settingsButton").mapToItem(surface.viewport, 0, 0);
            verify(point.y >= 0 && point.y + control("settingsButton").height <= surface.viewport.height);
            verify(surface.x >= 0 && surface.x + surface.width <= scene.width);
            verify(surface.y >= Metrics.barHeight && surface.y + surface.height <= scene.height);
            keyClick(Qt.Key_Return); focused("backButton");
            settingsModel.setColor("accent", "#abcdef");
            preview.coordinator.screens = [preview.secondScreen];
            tryCompare(preview.panelHost, "loaded", false);
            compare(Theme.accent, "#cba6f7"); verify(!settingsModel.editing);
        }
    }
}
