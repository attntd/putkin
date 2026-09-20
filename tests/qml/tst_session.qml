import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"

Item {
    id: scene
    width: 1366; height: 768
    MockSessionBackend { id: backend }
    SessionService { id: service; backend: backend; actionTimeout: 250 }
    MockBrightnessBackend { id: backlight }
    BrightnessService { id: brightness; backend: backlight }
    SessionController { service: service; coordinator: preview.coordinator; brightness: brightness }
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
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: panelLoader; sessionService: service }
    TestCase {
        name: "Session"
        when: windowShown
        property var originalCapabilities: null
        function initTestCase() { originalCapabilities = backend.capabilities; }
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            if (service.pending) { backend.cancel(service.pending.id); service.finish(service.pending.id, false, ""); }
            backend.reset(); backend.capabilities = originalCapabilities;
            service.lastError = ""; service.resultText = "";
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            scene.width = 1366; scene.height = 768;
            mouseMove(scene, 100, 700);
        }
        function cleanup() {
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
        }
        function control(name) { return findChild(preview.panelHost.window, name); }
        function open() {
            verify(preview.coordinator.open("power", preview.firstScreen, null));
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("power-logout").activeFocus);
        }
        function test_navigation_confirmation_cancel_and_single_request() {
            open();
            keyClick(Qt.Key_L); verify(control("power-reboot").activeFocus);
            keyClick(Qt.Key_L); verify(control("power-poweroff").activeFocus);
            keyClick(Qt.Key_H); verify(control("power-reboot").activeFocus);
            keyClick(Qt.Key_Return);
            tryVerify(() => control("powerCancel").activeFocus);
            compare(backend.calls.length, 0);
            keyClick(Qt.Key_Return); compare(backend.calls.length, 0);
            tryVerify(() => control("power-logout").activeFocus);
            keyClick(Qt.Key_L); keyClick(Qt.Key_Enter);
            tryVerify(() => control("powerCancel").activeFocus);
            keyClick(Qt.Key_L); verify(control("powerConfirm").activeFocus);
            keyClick(Qt.Key_H); verify(control("powerCancel").activeFocus);
            keyClick(Qt.Key_Tab); verify(control("powerConfirm").activeFocus);
            backend.automatic = false;
            keyClick(Qt.Key_Enter); keyClick(Qt.Key_Enter);
            compare(backend.calls, ["reboot"]);
            backend.settle(false, "Odmowa");
            compare(service.lastError, "Odmowa");
        }
        function test_escape_returns_to_menu_then_bar() {
            preview.barController.focusBar();
            preview.bar.focusQuickSettings();
            const invoker = findChild(preview.bar, "quickSettingsButton");
            preview.coordinator.open("power", preview.firstScreen, invoker);
            tryCompare(preview.panelHost, "loaded", true);
            keyClick(Qt.Key_Return);
            tryVerify(() => control("powerCancel").activeFocus);
            keyClick(Qt.Key_Escape);
            compare(preview.coordinator.activeId, "power"); compare(backend.calls.length, 0);
            keyClick(Qt.Key_Escape);
            tryCompare(preview.panelHost, "loaded", false);
            compare(preview.barController.screenName, "TEST-1");
        }
        function test_lock_confirm_suspend_and_resume_brightness() {
            backend.automatic = false;
            verify(service.request("suspend"));
            compare(backend.calls, ["lock-requested"]);
            verify(!service.request("suspend"));
            backend.confirmLock();
            compare(backend.calls, ["lock-requested", "lock-confirmed", "suspend"]);
            verify(!service.busy); compare(service.lastError, "");
            tryCompare(brightness, "busy", false);
            const count = backlight.requests.length;
            backend.resumed();
            tryVerify(() => backlight.requests.length > count);
        }
        function test_timeout_late_completion_and_backend_loss() {
            backend.automatic = false;
            service.request("suspend"); const old = service.pending.id;
            tryCompare(service, "busy", false);
            verify(service.lastError.length > 0);
            backend.confirmLock();
            compare(backend.calls, ["lock-requested"]);
            service.request("lock"); const current = service.pending.id;
            backend.completed(old, true, "spóźniony wynik");
            compare(service.pending.id, current);
            backend.ready = false;
            verify(!service.busy); verify(service.lastError.length > 0);
        }
        function test_disabled_actions_and_small_centered_menu() {
            open();
            const caps = Object.assign({}, backend.capabilities);
            caps.reboot = { available: false, reason: "Brak uprawnień." };
            caps.suspend = { available: false, reason: "Brak potwierdzenia blokady." };
            backend.capabilities = caps;
            keyClick(Qt.Key_L); verify(control("power-poweroff").activeFocus);
            keyClick(Qt.Key_J); verify(control("powerClose").activeFocus);
            verify(!service.request("suspend")); compare(backend.calls.length, 0);
            scene.width = 320; scene.height = 220;
            wait(30);
            const surface = preview.panelHost.window;
            verify(surface.x >= 0 && surface.x + surface.width <= scene.width);
            verify(surface.y >= Metrics.barHeight && surface.y + surface.height <= scene.height);
            const close = control("powerClose");
            const position = close.mapToItem(surface, 0, 0);
            verify(position.y >= 0 && position.y + close.height <= surface.height);
        }
        function test_quicksettings_lock_power_settings_and_errors() {
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            control("settingsButton").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_H); verify(control("lockButton").activeFocus);
            backend.automatic = false; keyClick(Qt.Key_Return);
            compare(backend.calls, ["lock-requested"]);
            backend.settle(false, "Brak potwierdzenia");
            compare(service.lastError, "Brak potwierdzenia");
            compare(control("sessionStatus"), null);
            control("powerButton").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            compare(preview.coordinator.activeId, "power");
            tryVerify(() => control("power-logout") !== null);
        }
        function test_confirmation_discarded_hotplug_replacement_and_reopen() {
            open(); keyClick(Qt.Key_Return);
            tryVerify(() => control("powerCancel").activeFocus);
            preview.coordinator.close(false);
            preview.coordinator.open("power", preview.firstScreen, null);
            tryVerify(() => control("power-logout").activeFocus);
            compare(preview.panelHost.window.page.confirmation, "");
            preview.coordinator.open("settings", preview.firstScreen, null);
            preview.coordinator.open("power", preview.secondScreen, null);
            compare(preview.panelHost.screen, preview.secondScreen);
            preview.coordinator.screens = [preview.firstScreen];
            tryCompare(preview.panelHost, "loaded", false);
            compare(backend.calls.length, 0);
        }
        function test_centered_geometry_and_twenty_cycles() {
            for (let i = 0; i < 20; ++i) {
                open();
                const surface = preview.panelHost.window;
                compare(surface.x, (scene.width - surface.width) / 2);
                compare(surface.y, (scene.height - surface.height) / 2);
                keyClick(Qt.Key_Return);
                tryVerify(() => control("powerCancel").activeFocus);
                preview.coordinator.close(false);
                tryCompare(preview.panelHost, "loaded", false);
            }
            compare(preview.createdCount, preview.destroyedCount);
            compare(backend.calls.length, 0);
        }
    }
}
