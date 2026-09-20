import QtQuick
import QtTest
import "../../services"
import "../../preview"

Item {
    id: scene
    width: 1366
    height: 768
    MockBluetoothBackend { id: backend }
    BluetoothService { id: bluetooth; backend: backend; actionTimeout: 180; radioTimeout: 180 }
    Component { id: deviceComponent; MockBluetoothDevice {} }
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
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: panelLoader; bluetooth: bluetooth }
    TestCase {
        name: "Bluetooth"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            bluetooth.invalidate("");
            backend.reset(); bluetooth.lastError = "";
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            scene.width = 1366; scene.height = 768;
            mouseMove(scene, 100, 700);
        }
        function cleanup() {
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            compare(backend.internal.discoveryChanges, 0);
            compare(backend.usb.discoveryChanges, 0);
        }
        function control(name) { return findChild(preview.panelHost.window, name); }
        function section() { return preview.panelHost.window.page.bluetoothSection; }
        function open() {
            preview.coordinator.open("bluetooth", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("bluetoothRadio").activeFocus);
        }
        function expand() { open(); keyClick(Qt.Key_L); verify(section().expanded); }
        function test_radio_requests_are_confirmed_and_serial() {
            backend.automatic = false;
            verify(bluetooth.setEnabled(false));
            verify(bluetooth.radioEnabled); verify(bluetooth.busy);
            verify(!bluetooth.setEnabled(true)); compare(backend.calls.length, 1);
            backend.settle(backend.operation, false, "");
            verify(bluetooth.busy); verify(bluetooth.radioEnabled);
            backend.internal.enabled = false;
            verify(!bluetooth.busy); verify(!bluetooth.radioEnabled);
            verify(bluetooth.setEnabled(true));
            backend.settle(backend.operation, false, "Odmowa");
            compare(bluetooth.lastError, "Odmowa"); verify(!bluetooth.radioEnabled);
            verify(bluetooth.setEnabled(true));
            tryCompare(bluetooth, "busy", false);
            verify(bluetooth.lastError.indexOf("Nie potwierdzono") >= 0);
        }
        function test_available_adapter_off_block_and_empty() {
            backend.available = false;
            compare(bluetooth.adapter, null); compare(bluetooth.devices.length, 0);
            verify(!bluetooth.setEnabled(true));
            backend.available = true; backend.adapters = [];
            compare(bluetooth.statusText, "Brak adaptera Bluetooth");
            backend.adapters = [backend.internal]; backend.internal.enabled = false;
            compare(bluetooth.statusText, "Bluetooth wyłączony");
            verify(!bluetooth.activate(backend.keyboard));
            backend.internal.state = 4;
            verify(bluetooth.blocked); verify(!bluetooth.setEnabled(true));
            backend.internal.state = 1; backend.internal.enabled = true;
            expand(); backend.internal.devices.reset([]);
            verify(control("bluetoothEmpty").visible);
        }
        function test_connect_disconnect_and_rejection() {
            expand(); keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            compare(backend.calls.length, 1); verify(!backend.headphones.connected);
            keyClick(Qt.Key_Enter); compare(backend.calls.length, 2); verify(backend.headphones.connected);
            backend.automatic = false;
            verify(bluetooth.activate(backend.keyboard));
            verify(!backend.keyboard.connected);
            verify(bluetooth.deviceStatus(backend.keyboard).indexOf("Łączenie") >= 0);
            verify(!bluetooth.activate(backend.keyboard));
            verify(!bluetooth.activate(backend.headphones));
            backend.settle(backend.operation, false, "Odmowa połączenia");
            compare(bluetooth.lastError, "Odmowa połączenia");
            verify(!backend.keyboard.connected);
            verify(bluetooth.activate(backend.keyboard));
            backend.settle(backend.operation, true, "");
            verify(backend.keyboard.connected); verify(!bluetooth.busy);
            verify(!bluetooth.activate(backend.nearby));
        }
        function test_multiple_adapters_and_late_operation() {
            backend.adapters = [backend.usb, backend.internal];
            compare(bluetooth.adapter, backend.internal);
            backend.automatic = false;
            bluetooth.activate(backend.keyboard);
            const old = backend.operation;
            bluetooth.selectAdapter(backend.usb);
            compare(bluetooth.devices[0], backend.mouse);
            backend.settle(old, false, "stara odmowa");
            compare(bluetooth.lastError, ""); compare(bluetooth.adapter, backend.usb);
            bluetooth.activate(backend.mouse);
            const current = backend.operation;
            backend.settle(old, true, "");
            verify(bluetooth.busy); compare(bluetooth.pending.target, backend.mouse);
            verify(!backend.mouse.connected);
            backend.settle(current, true, ""); verify(!bluetooth.busy);
            backend.usb.enabled = false;
            compare(bluetooth.adapter, backend.usb);
            backend.adapters = [backend.internal]; compare(bluetooth.adapter, backend.internal);
        }
        function test_device_loss_service_restart_and_timeout() {
            backend.automatic = false;
            bluetooth.activate(backend.keyboard); const old = backend.operation;
            backend.internal.devices.removeObject(backend.keyboard);
            verify(!bluetooth.busy); verify(bluetooth.lastError.length > 0);
            backend.settle(old, true, ""); verify(!bluetooth.busy);
            bluetooth.activate(backend.headphones);
            backend.available = false;
            verify(!bluetooth.busy); compare(bluetooth.deviceModel.count, 0);
            backend.available = true;
            compare(bluetooth.deviceModel.count, 1);
            bluetooth.activate(backend.headphones);
            tryCompare(bluetooth, "busy", false);
            verify(bluetooth.lastError.indexOf("Nie potwierdzono") >= 0);
        }
        function test_stable_focus_model_literal_names_and_battery() {
            expand(); keyClick(Qt.Key_J);
            const row = control("bluetoothDevice-0"); verify(row.activeFocus);
            backend.headphones.name = "<b>Słuchawki hjkl & goście</b>";
            for (let i = 0; i < 20; i++) backend.headphones.battery = i / 20;
            backend.headphones.connected = false;
            compare(control("bluetoothDevice-0"), row); verify(row.activeFocus);
            compare(row.contentItem.textFormat, Text.PlainText);
            compare(row.text, backend.headphones.name);
            verify(row.tooltip.indexOf(backend.headphones.name) >= 0);
            compare(row.Accessible.name, backend.headphones.name);
            verify(bluetooth.batteryText(backend.headphones).indexOf("Bateria urządzenia") >= 0);
            backend.headphones.batteryAvailable = false;
            compare(bluetooth.batteryText(backend.headphones), "");
            backend.nearby.paired = true;
            compare(bluetooth.deviceModel.count, 3); compare(control("bluetoothDevice-0"), row);
            backend.internal.devices.removeObject(backend.keyboard);
            compare(control("bluetoothDevice-0"), row); verify(row.activeFocus);
            backend.internal.devices.removeObject(backend.headphones);
            tryCompare(control("bluetoothExpand"), "activeFocus", true);
        }
        function test_keyboard_tooltip_manager_and_small_panel() {
            backend.adapters = [backend.internal, backend.usb];
            expand(); keyClick(Qt.Key_J); verify(control("bluetoothAdapter-hci0").activeFocus);
            keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            compare(bluetooth.adapter, backend.usb);
            keyClick(Qt.Key_J); verify(control("bluetoothDevice-0").activeFocus);
            const deviceRow = control("bluetoothDevice-0");
            wait(40); // Let the Column place the replacement adapter's rows.
            mouseMove(deviceRow, deviceRow.width / 2, deviceRow.height / 2);
            wait(650); compare(findChild(deviceRow, "tooltip"), null);
            mouseMove(scene, 100, 700);
            keyClick(Qt.Key_K); verify(control("bluetoothAdapter-hci1").activeFocus);
            keyClick(Qt.Key_Up); keyClick(Qt.Key_K); keyClick(Qt.Key_H);
            verify(control("bluetoothRadio").activeFocus);
            scene.width = 320; scene.height = 220;
            const manager = control("bluetoothManager"); manager.forceActiveFocus();
            keyClick(Qt.Key_Return); compare(backend.managerCalls, 1);
            compare(control("bluetoothManagerError"), null);
            verify(backend.managerError.length > 0);
            wait(40);
            const p = manager.mapToItem(preview.panelHost.window, 0, 0);
            verify(p.y >= 0 && p.y + manager.height <= preview.panelHost.window.height);
            backend.managerAvailable = true;
            keyClick(Qt.Key_Enter);
            tryCompare(preview.panelHost, "loaded", false);
            compare(preview.barController.screenName, "");
        }
        function test_close_paths_data() {
            return ["escape", "outside", "replace", "monitor", "destroy", "disabled"].map(tag => ({tag: tag, action: tag}));
        }
        function test_close_paths(data) {
            expand(); backend.automatic = false; bluetooth.activate(backend.keyboard);
            if (data.action === "escape") { keyClick(Qt.Key_Escape); compare(preview.coordinator.activeId, ""); }
            else if (data.action === "outside") mouseClick(preview, 500, 500);
            else if (data.action === "replace") preview.coordinator.open("settings", preview.firstScreen, null);
            else if (data.action === "monitor") preview.coordinator.screens = [preview.secondScreen];
            else if (data.action === "destroy") panelLoader.activeAsync = false;
            else section().enabled = false;
            // Closing a view does not cancel an already requested connection.
            backend.settle(backend.operation, true, "");
            verify(backend.keyboard.connected); verify(!bluetooth.busy);
        }
        function test_twenty_cycles() {
            for (let i = 0; i < 20; i++) {
                expand(); preview.coordinator.close(false);
                tryCompare(preview.panelHost, "loaded", false);
            }
            compare(preview.createdCount, preview.destroyedCount);
            compare(backend.calls.length, 0);
        }
    }
}
