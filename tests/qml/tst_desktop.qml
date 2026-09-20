import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/wallpaper"

Item {
    id: scene
    width: 1000; height: 800
    MockNightLightBackend { id: backend }
    NightLightService { id: night; backend: backend }
    readonly property alias nightModel: night
    MockBrightnessBackend { id: brightnessBackend }
    BrightnessService { id: brightness; backend: brightnessBackend }
    readonly property alias brightnessModel: brightness
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notifications; backend: notificationBackend; screens: preview.coordinator.screens; monitorService: preview.backend }
    readonly property alias notificationModel: notifications
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
        nightLight: scene.nightModel
        brightness: scene.brightnessModel
        notifications: scene.notificationModel
    }
    WallpaperService { id: wallpaper }
    Item {
        id: desktop
        width: 320; height: 180
        visible: false
        property int clicks: 0
        MouseArea { anchors.fill: parent; onClicked: desktop.clicks++ }
        WallpaperView { id: background; anchors.fill: parent; service: wallpaper }
    }
    TestCase {
        name: "DesktopExtras"
        when: windowShown
        function control(name) { return findChild(preview.panelHost.window, name); }
        function settle() { tryCompare(night, "busy", false); }
        function open() {
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            settle();
            // The async Loader queues initial focus after reporting Ready.
            // Start keyboard actions only after that handoff, like other panel tests.
            tryVerify(() => preview.panelHost.window.page && preview.panelHost.window.page.firstControl.activeFocus);
            verify(waitForPolish(scene));
        }
        function writes() { return backend.requests.filter(request => request.arguments[0] === "set"); }
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            settle();
            backend.reset(); night.refresh(); settle();
            scene.width = 1000; scene.height = 800;
            wallpaper.selection = ""; desktop.visible = false;
            mouseMove(scene, 10, 780);
        }
        function cleanup() {
            backend.automatic = true;
            if (night.busy) backend.deliver(backend.requests[backend.requests.length - 1]);
            settle();
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            wallpaper.selection = ""; desktop.visible = false;
        }
        function test_existing_state_no_start_or_write() {
            open();
            compare(night.enabled, true); compare(night.temperature, 4500);
            compare(control("nightLightToggle").checked, true);
            compare(writes().length, 0);
            verify(backend.requests.every(request => request.arguments[0] === "read"));
        }
        function test_absent_backend_has_no_switch_and_recovers() {
            backend.present = false; open();
            verify(!night.available);
            verify(!control("nightLightToggle").enabled);
            verify(!control("nightLightTemperature").visible);
            verify(night.lastError.length > 0);
            compare(control("nightLightError"), null);
            control("brightnessDetails").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_J); verify(control("notificationDnd").activeFocus);
            verify(control("nightLightRefresh") === null);
            backend.present = true;
            preview.coordinator.close(false); open();
            verify(night.available); compare(writes().length, 0);
        }
        function test_confirmation_no_optimism_or_double_write() {
            open();
            backend.automatic = false;
            control("nightLightToggle").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            verify(night.busy); compare(night.enabled, true);
            compare(control("nightLightToggle").checked, true);
            keyClick(Qt.Key_Return); compare(writes().length, 1);
            backend.deliver(backend.requests[backend.requests.length - 1]); settle();
            compare(night.enabled, false); verify(!control("nightLightTemperature").visible);
        }
        function test_failure_data() {
            return ["timeout", "denied", "restart", "version", "protocol", "unconfirmed"].map(code => ({tag: code, code: code}));
        }
        function test_failure(data) {
            open(); backend.failure = data.code;
            control("nightLightToggle").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return); settle();
            verify(!night.available); compare(backend.enabled, true);
            verify(night.lastError.length > 0);
            tryVerify(() => control("notificationDnd").activeFocus);
            wait(30); compare(writes().length, 1);
        }
        function test_keyboard_temperature_and_section_order() {
            open();
            control("brightnessDetails").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_J); verify(control("notificationDnd").activeFocus);
            keyClick(Qt.Key_L); verify(control("nightLightToggle").activeFocus);
            keyClick(Qt.Key_J); verify(control("nightLightTemperature").activeFocus);
            keyClick(Qt.Key_H); settle(); compare(night.temperature, 4400);
            control("nightLightTemperature").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_L); settle(); compare(night.temperature, 4500);
            control("nightLightTemperature").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right); settle(); compare(night.temperature, 4600);
            control("nightLightTemperature").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_J); verify(control("settingsButton").activeFocus);
            keyClick(Qt.Key_K); verify(control("nightLightTemperature").activeFocus);
            keyClick(Qt.Key_K); verify(control("nightLightToggle").activeFocus);
            keyClick(Qt.Key_K); verify(control("brightnessSlider").activeFocus);
        }
        function test_temperature_bounds_and_external_refresh() {
            for (const value of [999, 6501, NaN, Infinity, "4500", null]) verify(!night.setTemperature(value));
            for (const value of [1000, 6500]) { verify(night.setTemperature(value)); settle(); compare(night.temperature, value); }
            backend.temperature = 3000; backend.enabled = false;
            night.refresh(); settle(); compare(night.enabled, false); compare(night.temperature, 3000);
            verify(night.setEnabled(true)); settle(); compare(night.temperature, 6500);
        }
        function test_restart_rejects_stale_action_without_retry() {
            backend.owner = "43:200";
            verify(night.setEnabled(false)); settle();
            verify(!night.available); compare(backend.enabled, true);
            compare(writes().length, 1);
            night.refresh(); settle(); compare(night.sample.owner, "43:200");
        }
        function test_small_panel_scroll_and_lifecycle() {
            scene.width = 320; scene.height = 220;
            open();
            control("nightLightTemperature").forceActiveFocus(Qt.TabFocusReason);
            wait(30);
            const surface = preview.panelHost.window;
            const button = control("nightLightTemperature");
            const position = button.mapToItem(surface.viewport, 0, 0);
            verify(position.y >= 0); verify(position.y + button.height <= surface.viewport.height);
            keyClick(Qt.Key_Escape); keyClick(Qt.Key_Escape);
            tryCompare(preview.panelHost, "loaded", false);
            tryCompare(preview, "createdCount", preview.destroyedCount);
        }
        function test_wallpaper_fallback_path_and_input() {
            wallpaper.selection = "solid";
            verify(wallpaper.enabled); compare(wallpaper.source.toString(), "");
            desktop.visible = true;
            compare(background.color, Theme.background); verify(background.fallbackVisible);
            const clicks = desktop.clicks;
            mouseClick(desktop, 100, 100); compare(desktop.clicks, clicks + 1);
            wallpaper.selection = "https://example.invalid/wallpaper.png";
            compare(wallpaper.source.toString(), ""); verify(wallpaper.diagnostic.length > 0);
        }
        function test_wallpaper_missing_file_falls_back() {
            ignoreWarning(/QML QQuickImage: Cannot open: file:\/\/\/tmp\/putkin-no-wallpaper-11.png/);
            wallpaper.selection = "/tmp/putkin-no-wallpaper-11.png";
            tryCompare(background, "imageStatus", Image.Error);
            verify(background.fallbackVisible);
            verify(background.diagnostic.length > 0);
        }
        function test_wallpaper_image_load_and_release() {
            const file = Qt.resolvedUrl("../fixtures/notification-image.svg").toString().replace(/^file:\/\//, "");
            wallpaper.selection = file;
            tryCompare(background, "imageStatus", Image.Ready);
            verify(!background.fallbackVisible);
            background.pixelScale = 2;
            tryCompare(background, "imageStatus", Image.Ready);
            wallpaper.selection = "solid";
            tryCompare(background, "imageStatus", Image.Null);
            verify(background.fallbackVisible);
            wallpaper.selection = ""; verify(!wallpaper.enabled);
        }
    }
}
