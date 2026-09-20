import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"

Item {
    id: scene
    width: 1366
    height: 768
    MockNetworkBackend {
        id: backend
    }
    NetworkService {
        id: network
        backend: backend
        actionTimeout: 150
        radioTimeout: 150
    }
    Component {
        id: leaseComponent
        NetworkScanLease {}
    }
    Component {
        id: deviceComponent
        MockNetworkDevice {}
    }
    Component {
        id: networkComponent
        MockNetwork {}
    }
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
        network: network
    }
    TestCase {
        name: "Network"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            preview.barController.close();
            network.cancel();
            network.lastError = "";
            backend.reset();
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            scene.width = 1366;
            scene.height = 768;
            mouseMove(scene, 150, 700);
            wait(10);
        }
        function cleanup() {
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            compare(network.scanRequests, 0);
            compare(backend.wifi.scannerEnabled, false);
        }
        function control(name) {
            return findChild(preview.panelHost.window, name);
        }
        function section() {
            return preview.panelHost.window.page.networkSection;
        }
        function open() {
            mouseClick(preview.bar.networkButton);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("wifiRadio").activeFocus);
        }
        function expand() {
            open();
            keyClick(Qt.Key_L);
            tryCompare(backend.wifi, "scannerEnabled", true);
            compare(network.scanRequests, 1);
        }
        function prompt() {
            expand();
            control("wifiNetwork-0-2").forceActiveFocus();
            keyClick(Qt.Key_Return);
            tryVerify(() => control("wifiPassword").activeFocus);
        }
        function test_status_and_internet_data() {
            return [
                {
                    tag: "unknown",
                    value: 0,
                    text: "stan nieznany"
                },
                {
                    tag: "none",
                    value: 1,
                    text: "Brak dostępu"
                },
                {
                    tag: "portal",
                    value: 2,
                    text: "Portal"
                },
                {
                    tag: "limited",
                    value: 3,
                    text: "Ograniczony"
                },
                {
                    tag: "full",
                    value: 4,
                    text: "Dostęp do internetu"
                }
            ];
        }
        function test_status_and_internet(data) {
            backend.connectivity = data.value;
            backend.ethernet.state = 2;
            verify(network.ethernetConnected);
            compare(network.activeWifi.length, 1);
            compare(network.indicator, "LAN");
            verify(network.internetText.indexOf(data.text) >= 0);
            open();
            compare(preview.bar.networkButton.Accessible.name, network.statusText);
            backend.connectivityCheckEnabled = false;
            verify(network.internetText.indexOf("stan nieznany") >= 0);
        }
        function test_unavailable_no_wifi_blocked_and_radio_confirmation() {
            backend.available = false;
            compare(network.devices.length, 0);
            compare(network.activeWifi.length, 0);
            verify(!network.setWifiEnabled(true));
            backend.available = true;
            backend.devices = [backend.ethernet];
            compare(network.wifiText, "Brak adaptera Wi-Fi");
            verify(!network.setWifiEnabled(true));
            backend.devices = [backend.wifi, backend.ethernet];
            backend.wifiEnabled = false;
            backend.hardwareEnabled = false;
            verify(!network.setWifiEnabled(true));
            compare(backend.radioCalls, 0);
            backend.hardwareEnabled = true;
            backend.confirmRadio = false;
            verify(network.setWifiEnabled(true));
            verify(network.radioBusy);
            verify(!network.wifiEnabled);
            // An optimistic property is not a confirmation signal.
            backend.wifiEnabled = true;
            verify(network.radioBusy);
            backend.radioConfirmed();
            verify(!network.radioBusy);
            network.setWifiEnabled(false);
            tryCompare(network, "radioBusy", false);
            verify(network.lastError.indexOf("Nie potwierdzono") >= 0);
            verify(network.wifiEnabled);
            open();
            backend.hardwareEnabled = false;
            verify(!control("wifiRadio").enabled);
            verify(!control("wifiRadio").highlighted);
            tryCompare(control("wifiExpand"), "activeFocus", true);
            backend.available = false;
            verify(!control("networkCheck").enabled);
        }
        function test_scans_are_owned_and_stop_on_unavailable() {
            compare(backend.wifi.scannerEnabled, false);
            const a = createTemporaryObject(leaseComponent, scene, {
                active: true,
                network: network
            });
            const b = createTemporaryObject(leaseComponent, scene, {
                active: true,
                network: network
            });
            compare(network.scanRequests, 2);
            verify(backend.wifi.scannerEnabled);
            a.active = false;
            verify(backend.wifi.scannerEnabled);
            b.active = false;
            verify(!backend.wifi.scannerEnabled);
            backend.wifi.scannerEnabled = true;
            a.active = true;
            a.active = false;
            verify(backend.wifi.scannerEnabled);
            backend.wifi.scannerEnabled = false;
            a.active = true;
            backend.available = false;
            verify(!backend.wifi.scannerEnabled);
            a.active = false;
            backend.available = true;
        }
        function test_close_paths_data() {
            return ["escape", "outside", "button", "replace", "monitor", "destroy", "radio", "hardware", "adapter", "unavailable", "disabled"].map(tag => ({
                        tag: tag,
                        action: tag
                    }));
        }
        function test_close_paths(data) {
            prompt();
            const field = control("wifiPassword");
            keyClick(Qt.Key_H);
            keyClick(Qt.Key_J);
            keyClick(Qt.Key_K);
            keyClick(Qt.Key_L);
            compare(field.text, "hjkl");
            verify(field.activeFocus);
            if (data.action === "escape") {
                keyClick(Qt.Key_Escape);
                compare(field.text, "");
                keyClick(Qt.Key_Escape);
            } else if (data.action === "outside")
                mouseClick(preview, 500, 500);
            else if (data.action === "button")
                preview.coordinator.close(true);
            else if (data.action === "replace")
                preview.coordinator.open("settings", preview.firstScreen, null);
            else if (data.action === "monitor")
                preview.coordinator.screens = [preview.secondScreen];
            else if (data.action === "destroy")
                panelLoader.activeAsync = false;
            else if (data.action === "radio")
                network.setWifiEnabled(false);
            else if (data.action === "hardware")
                backend.hardwareEnabled = false;
            else if (data.action === "adapter")
                backend.devices = [backend.ethernet];
            else if (data.action === "unavailable")
                backend.available = false;
            else if (data.action === "disabled")
                section().enabled = false;
            tryCompare(network, "scanRequests", 0);
            verify(!backend.wifi.scannerEnabled);
            verify(!network.target);
            if (field)
                compare(field.text, "");
        }
        function test_open_saved_and_disconnect() {
            expand();
            verify(network.activate(backend.cafe));
            compare(backend.cafe.connects, 1);
            verify(backend.cafe.connected);
            verify(!network.busy);
            verify(network.activate(backend.cafe));
            compare(backend.cafe.disconnects, 1);
            verify(!backend.cafe.connected);
            backend.home.state = 4;
            verify(network.activate(backend.home));
            compare(backend.home.connects, 1);
            verify(backend.home.connected);
            compare(backend.home.pskCalls, 0);
            verify(!network.needsPassword);
        }
        function test_psk_retry_clear_and_no_text_navigation() {
            prompt();
            const field = control("wifiPassword");
            backend.secure.rejectPsk = true;
            for (let i = 0; i < 2; i++) {
                keyClick(Qt.Key_H);
                keyClick(Qt.Key_J);
                keyClick(Qt.Key_K);
                keyClick(Qt.Key_L);
            }
            compare(field.text, "hjklhjkl");
            keyClick(Qt.Key_Return);
            compare(backend.secure.pskCalls, 1);
            compare(backend.secure.passwordLength, 8);
            verify(network.needsPassword);
            compare(field.text, "");
            backend.secure.rejectPsk = false;
            field.text = "a-test-only-password";
            keyClick(Qt.Key_Enter);
            verify(backend.secure.connected);
            verify(!network.needsPassword);
            compare(field.text, "");
            compare(backend.secure.connects, 1);
            compare(backend.secure.pskCalls, 2);
        }
        function test_timeout_switch_target_and_stale_result() {
            expand();
            backend.secure.automatic = false;
            network.activate(backend.secure);
            const serial = network.serial;
            backend.cafe.automatic = false;
            network.activate(backend.cafe);
            backend.secure.connectionFailed(1);
            compare(network.target, backend.cafe);
            verify(!network.needsPassword);
            verify(!network.providePsk(backend.secure, serial, "obsolete"));
            compare(backend.secure.pskCalls, 0);
            tryCompare(network, "busy", false);
            verify(network.lastError.indexOf("Przekroczono czas") >= 0);
            verify(backend.wifi.disconnects > 0);
        }
        function test_stable_delegate_literal_ssid_empty_and_duplicates() {
            expand();
            const row = control("wifiNetwork-0-0");
            row.forceActiveFocus();
            backend.home.name = "<b>hjkl & goście</b>";
            for (let i = 0; i < 20; i++)
                backend.home.signalStrength = i / 20;
            compare(control("wifiNetwork-0-0"), row);
            verify(row.activeFocus);
            compare(row.contentItem.textFormat, Text.PlainText);
            verify(row.contentItem.text.indexOf(backend.home.name) === 0);
            const device = createTemporaryObject(deviceComponent, scene, {
                name: "wlan1"
            });
            const duplicate = createTemporaryObject(networkComponent, scene, {
                name: backend.home.name,
                device: device,
                security: 10
            });
            device.networks.reset([duplicate]);
            backend.devices = [backend.wifi, device];
            tryVerify(() => control("wifiNetwork-1-0") !== null);
            verify(device.scannerEnabled);
            network.activate(duplicate);
            compare(duplicate.connects, 1);
            compare(backend.home.connects, 0);
            backend.devices = [backend.wifi];
            verify(!device.scannerEnabled);
            backend.wifi.networks.reset([]);
            tryCompare(control("wifiExpand"), "activeFocus", true);
            compare(network.activeWifi.length, 0);
        }
        function test_keyboard_editor_and_small_geometry() {
            expand();
            keyClick(Qt.Key_J);
            compare(control("wifiNetwork-0-0").activeFocus, true);
            keyClick(Qt.Key_J);
            compare(control("wifiNetwork-0-1").activeFocus, true);
            compare(control("wifiNetwork-0-1").upTarget, control("wifiNetwork-0-0"));
            keyClick(Qt.Key_K);
            compare(preview.Window.window.activeFocusItem.objectName, "wifiNetwork-0-0");
            keyClick(Qt.Key_Up);
            compare(preview.Window.window.activeFocusItem.objectName, "wifiExpand");
            keyClick(Qt.Key_H);
            compare(control("wifiRadio").activeFocus, true);
            scene.width = 320;
            scene.height = 220;
            const editor = control("networkEditor");
            editor.forceActiveFocus();
            keyClick(Qt.Key_Return);
            compare(backend.editorCalls, 1);
            verify(backend.editorError.length > 0);
            verify(preview.panelHost.window.height <= preview.panelHost.availableHeight);
            wait(50);
            const position = editor.mapToItem(preview.panelHost.window, 0, 0);
            verify(position.y >= 0 && position.y + editor.height <= preview.panelHost.window.height);
            backend.enterprise.known = true;
            network.activate(backend.enterprise);
            compare(backend.enterprise.connects, 0);
            verify(network.lastError.indexOf("edytora") >= 0);
        }
        function test_managed_devices_release_independently() {
            expand();
            const device = createTemporaryObject(deviceComponent, scene, {name: "wlan1"});
            backend.devices = [backend.wifi, device];
            verify(device.scannerEnabled); verify(backend.wifi.scannerEnabled);
            backend.secure.automatic = false;
            network.activate(backend.secure);
            backend.wifi.nmManaged = false;
            verify(!backend.wifi.scannerEnabled); verify(device.scannerEnabled);
            verify(!network.target); verify(!network.busy);
            backend.devices = [backend.wifi];
            verify(!device.scannerEnabled);
            backend.wifi.nmManaged = true;
            verify(backend.wifi.scannerEnabled);
            backend.home.name = "one\ntwo\t<b>";
            compare(network.label(backend.home), "one two <b>");
            compare(backend.home.name, "one\ntwo\t<b>");
        }
        function test_twenty_cycles() {
            const starts = backend.wifi.scanStarts, stops = backend.wifi.scanStops;
            for (let i = 0; i < 20; ++i) {
                expand();
                preview.coordinator.close(false);
                compare(network.scanRequests, 0);
                verify(!backend.wifi.scannerEnabled);
                tryCompare(preview.panelHost, "loaded", false);
            }
            compare(backend.wifi.scanStarts - starts, 20);
            compare(backend.wifi.scanStops - stops, 20);
            tryCompare(preview, "createdCount", preview.destroyedCount);
        }
    }
}
