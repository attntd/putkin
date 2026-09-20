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
        property bool asynchronous: false
        readonly property bool active: loader.status === Loader.Ready
        readonly property var item: active ? loader.item : null
        readonly property Loader loader: Loader { active: panelLoader.activeAsync; asynchronous: panelLoader.asynchronous; sourceComponent: preview.panelComponent }
    }
    PanelPreviewScene {
        id: preview
        anchors.fill: parent
        panelLoader: panelLoader
        audio: audio; brightness: brightness; network: network; bluetooth: bluetooth
        nightLight: night; caffeinate: caffeinate; battery: battery; powerProfiles: profiles; sessionService: session
        notifications: notices; tray: tray; trayMenuComponent: tray.menuComponent
    }
    Component { id: nodeComponent; MockAudioNode {} }
    TestCase {
        name: "QuickMenu"
        when: windowShown
        function control(name) { return findChild(preview.panelHost.window, name); }
        function open(surface) {
            preview.coordinator.open(surface || "quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => preview.panelHost.window.page !== null);
            tryVerify(() => control(surface === "notifications" ? "notificationDnd" : "audioVolume").activeFocus);
            tryCompare(night, "busy", false);
            verify(waitForPolish(scene));
        }
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            panelLoader.asynchronous = false;
            scene.width = 1366; scene.height = 900;
            preview.errorNotificationsEnabled = true;
            preview.barController.close();
            audioBackend.reset(); brightnessBackend.reset(); networkBackend.reset(); bluetoothBackend.reset(); nightBackend.reset(); caffeinateBackend.reset(); caffeinate.selectedMode = "presentation";
            audio.lastError = ""; network.lastError = ""; bluetooth.lastError = "";
            notices.clear(); notices.dnd = false;
            mouseMove(scene, 100, 800);
            wait(30);
        }
        function cleanup() {
            preview.coordinator.close(false); notices.clear(); preview.osd.hide();
            tryCompare(preview.panelHost, "loaded", false);
            compare(network.scanRequests, 0);
        }
        function rings(item) {
            let result = [];
            if (item.objectName === "focusIndicator" && item.visible) result.push(item);
            for (const child of item.children) result = result.concat(rings(child));
            return result;
        }
        function test_audio_is_one_keyboard_row() {
            open();
            const slider = control("audioVolume");
            tryVerify(() => slider.activeFocus);
            const row = control("audioRow");
            compare(rings(row).length, 1);
            compare(rings(row)[0].width, row.width);
            const value = audio.volume;
            keyClick(Qt.Key_L); tryCompare(audio, "volume", value + 5);
            keyClick(Qt.Key_H); tryCompare(audio, "volume", value);
            keyClick(Qt.Key_Return); verify(preview.panelHost.window.page.audioSection.expanded);
            compare(audio.volume, value);
            keyClick(Qt.Key_I); verify(!preview.panelHost.window.page.audioSection.expanded);
            keyClick(Qt.Key_Tab); verify(control("brightnessSlider").activeFocus);
            keyClick(Qt.Key_K); verify(slider.activeFocus);
            keyClick(Qt.Key_I); keyClick(Qt.Key_J); verify(control("audioOutput-speakers").activeFocus);
            keyClick(Qt.Key_K); verify(slider.activeFocus);
            mouseClick(control("audioOutputs")); compare(rings(row).length, 0);
            keyClick(Qt.Key_L); tryCompare(audio, "volume", value + 5);
            compare(rings(row).length, 1);
            mouseClick(slider, slider.width * 0.6, slider.height / 2);
            compare(rings(row).length, 0);
        }
        function test_toggle_grid_geometry_focus_and_navigation() {
            open();
            const page = preview.panelHost.window.page;
            const tiles = page.tiles;
            compare(tiles.length, 5);
            for (let index = 0; index < tiles.length; ++index) {
                const tile = tiles[index];
                verify(tile.width > tile.height * 2);
                compare(tile.x, index % 2 ? tiles[0].width + Metrics.space12 : 0);
                compare(tile.y, Math.floor(index / 2) * (tile.height + Metrics.space12));
                const icon = tile.contentItem.children[0], label = tile.contentItem.children[1];
                compare(label.x, icon.x + icon.width + Metrics.space8);
                verify(!label.truncated, tile.text);
            }
            keyClick(Qt.Key_J); keyClick(Qt.Key_J); verify(tiles[0].activeFocus);
            keyClick(Qt.Key_L); verify(tiles[1].activeFocus);
            keyClick(Qt.Key_J); verify(tiles[3].activeFocus);
            keyClick(Qt.Key_H); verify(tiles[2].activeFocus);
            compare(rings(tiles[2])[0].width, tiles[2].width);
            keyClick(Qt.Key_Return); verify(notices.dnd);
            compare(rings(tiles[2])[0].width, tiles[2].width + 2 * Metrics.focusOffset);
            keyClick(Qt.Key_J); verify(tiles[4].activeFocus);
            keyClick(Qt.Key_K); verify(tiles[2].activeFocus);
            for (const index of [3, 4]) { keyClick(Qt.Key_Tab); verify(tiles[index].activeFocus); }
            mouseClick(tiles[2]); verify(!notices.dnd); compare(rings(page).length, 0);
        }
        function test_brightness_and_temperature_focus_span_the_row_data() {
            return [
                {tag: "brightness-slider", control: "brightnessSlider", row: "brightnessRow", slider: "brightnessSlider"},
                {tag: "brightness-details", control: "brightnessDetails", row: "brightnessRow", slider: "brightnessSlider"},
                {tag: "temperature", control: "nightLightTemperature", row: "nightLightTemperatureRow", slider: "nightLightTemperature"}
            ];
        }
        function test_brightness_and_temperature_focus_span_the_row(data) {
            open();
            tryCompare(preview.panelHost.window, "opacity", 1);
            const target = control(data.control), row = control(data.row), slider = control(data.slider);
            verify(target.visible && target.enabled);
            target.forceActiveFocus(Qt.TabFocusReason);
            const indicators = rings(row);
            compare(indicators.length, 1);
            compare(indicators[0].width, control("audioRow").width);
            compare(indicators[0].height, row.height);
            compare(indicators[0].mapToItem(row, 0, 0), Qt.point(0, 0));
            compare(slider.drawFocus, false);
            mouseClick(target, target.width / 2, target.height / 2);
            compare(rings(row).length, 0);
            tryCompare(brightness, "busy", false); tryCompare(night, "busy", false);
            target.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Tab); keyClick(Qt.Key_Backtab);
            compare(rings(row).length, 1);
            keyClick(Qt.Key_J);
            compare(rings(row).length, 0);
        }
        function test_caffeinate_modes_navigation_round_trip_data() {
            const rows = [];
            for (const small of [false, true]) {
                for (const keys of [
                    { tag: "vim", down: Qt.Key_J, up: Qt.Key_K },
                    { tag: "arrows", down: Qt.Key_Down, up: Qt.Key_Up },
                    { tag: "tab", down: Qt.Key_Tab, up: Qt.Key_Backtab, modifiers: Qt.ShiftModifier }
                ]) rows.push({ tag: keys.tag + (small ? "-small" : "-normal"), small: small, keys: keys });
            }
            return rows;
        }
        function test_caffeinate_modes_navigation_round_trip(data) {
            panelLoader.asynchronous = true;
            if (data.small) { scene.width = 320; scene.height = 220; }
            for (let cycle = 0; cycle < 3; ++cycle) {
                open();
                const page = preview.panelHost.window.page;
                const tile = control("caffeinateToggle");
                tile.forceActiveFocus(Qt.TabFocusReason);
                keyClick(Qt.Key_I);
                verify(page.caffeinateExpanded);
                keyClick(data.keys.down); verify(control("caffeinateMode-presentation").activeFocus);
                keyClick(data.keys.down); verify(control("caffeinateMode-background").activeFocus);
                keyClick(data.keys.up, data.keys.modifiers || Qt.NoModifier);
                verify(control("caffeinateMode-presentation").activeFocus, "Return from background to presentation");
                keyClick(data.keys.up, data.keys.modifiers || Qt.NoModifier);
                verify(tile.activeFocus, "Return from presentation to Caffeinate");
                keyClick(data.keys.up, data.keys.modifiers || Qt.NoModifier);
                verify(control(data.keys.tag === "tab" ? "nightLightToggle" : "notificationDnd").activeFocus);
                verify(page.caffeinateExpanded);
                compare(caffeinateBackend.requests.length, 0);
                preview.coordinator.close(false);
                tryCompare(preview.panelHost, "loaded", false);
            }
        }
        function test_caffeinate_modes_keyboard_mouse_and_confirmed_state() {
            open();
            const page = preview.panelHost.window.page, tile = control("caffeinateToggle");
            tile.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_I); verify(page.caffeinateExpanded);
            compare(caffeinateBackend.requests.length, 0);
            keyClick(Qt.Key_J); verify(control("caffeinateMode-presentation").activeFocus);
            keyClick(Qt.Key_J); verify(control("caffeinateMode-background").activeFocus);
            caffeinateBackend.automatic = false;
            keyClick(Qt.Key_Return);
            verify(!page.caffeinateExpanded); verify(caffeinate.busy); verify(!tile.checked);
            compare(caffeinateBackend.requests.join(), "background");
            caffeinateBackend.settle();
            tryVerify(() => tile.activeFocus); verify(tile.checked);
            compare(caffeinate.mode, "background"); compare(caffeinate.selectedMode, "background");
            keyClick(Qt.Key_Return); verify(tile.checked); caffeinateBackend.settle();
            tryVerify(() => tile.activeFocus); verify(!tile.checked);
            caffeinateBackend.automatic = true;
            mouseClick(tile, tile.width / 2, tile.height / 2, Qt.RightButton);
            verify(page.caffeinateExpanded); compare(caffeinate.mode, "off"); compare(rings(page).length, 0);
            wait(Metrics.panelFade + 20);
            mouseClick(control("caffeinateMode-presentation"));
            compare(caffeinate.mode, "presentation"); verify(!page.caffeinateExpanded); compare(rings(page).length, 0);
            preview.coordinator.close(false); tryCompare(preview.panelHost, "loaded", false);
            open(); compare(caffeinate.mode, "presentation");
            compare(notices.history.length, 0); compare(notices.entries.length, 0);
        }
        function test_caffeinate_rejection_only_notifies_and_keeps_previous_mode() {
            open();
            const tile = control("caffeinateToggle");
            mouseClick(tile); compare(caffeinate.mode, "presentation");
            caffeinateBackend.reject = true;
            tile.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_I); keyClick(Qt.Key_J); keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            compare(caffeinate.mode, "presentation"); compare(caffeinate.selectedMode, "presentation");
            tryVerify(() => notices.history.length === 1);
            verify(notices.entries[0].body.includes("Odmowa"));
            verify(!control("notificationCenterButton"));
        }
        function test_small_grid_and_modes_remain_reachable() {
            scene.width = 320; scene.height = 220; open();
            for (let cycle = 0; cycle < 5; ++cycle) {
                control("caffeinateToggle").forceActiveFocus(Qt.TabFocusReason);
                keyClick(Qt.Key_I); keyClick(Qt.Key_J); keyClick(Qt.Key_J);
                const button = control("caffeinateMode-background");
                tryVerify(() => button.activeFocus);
                wait(Metrics.panelFade + 20);
                const scroll = preview.panelHost.window.viewport;
                const position = button.mapToItem(scroll, 0, 0);
                verify(position.y >= -1 && position.y + button.height <= scroll.height + 1);
                keyClick(Qt.Key_Return); compare(caffeinate.mode, "background");
            }
        }
        function test_distinct_audio_names_follow_device_not_default() {
            const nodes = ["Speaker", "Headphones", "HDMI1", "HDMI2", "HDMI3"].map(kind => createTemporaryObject(nodeComponent, scene, {
                name: "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__" + kind + "__sink",
                description: "Core Ultra Processors (Series 3) HD Audio " + kind
            }));
            audioBackend.devices = nodes; audioBackend.defaultDevice = nodes[0];
            compare(audio.outputName, "Wbudowane głośniki");
            compare(nodes.map(node => audio.label(node)).join("|"), "Wbudowane głośniki|Słuchawki|HDMI / DisplayPort 1|HDMI / DisplayPort 2|HDMI / DisplayPort 3");
            audioBackend.defaultDevice = nodes[1];
            compare(audio.outputName, "Słuchawki"); compare(audio.label(nodes[0]), "Wbudowane głośniki");
            nodes[2].description = "USB Audio"; nodes[2].name = "usb-a";
            nodes[3].description = "USB Audio"; nodes[3].name = "usb-b";
            verify(audio.label(nodes[2]) !== audio.label(nodes[3]));
            const label = audio.label(nodes[2]);
            audioBackend.devices = nodes.slice().reverse(); compare(audio.label(nodes[2]), label);
        }
        function test_audio_becoming_ready_keeps_row_focus() {
            audioBackend.defaultDevice = null;
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("audioOutputs").activeFocus);
            audioBackend.defaultDevice = audioBackend.speakers;
            tryCompare(audio, "available", true);
            verify(control("audioOutputs").activeFocus);
            keyClick(Qt.Key_L); tryCompare(audio, "volume", 47);
            compare(rings(control("audioRow")).length, 1);
            keyClick(Qt.Key_Tab); verify(control("brightnessSlider").activeFocus);
        }
        function test_tiles_toggle_without_management_or_progress_messages() {
            open();
            for (const name of ["wifiExpand", "bluetoothExpand", "networkCheck", "bluetoothManager", "notificationCenterButton", "nightLightExpand", "nightLightRefresh"])
                compare(control(name), null, name);
            compare(network.scanRequests, 0);
            const wifi = control("wifiRadio");
            const bt = control("bluetoothRadio");
            compare(wifi.y, bt.y); compare(wifi.height, bt.height);
            networkBackend.confirmRadio = false;
            wifi.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            verify(network.radioBusy); verify(wifi.checked); compare(wifi.text, "Wi-Fi");
            compare(networkBackend.radioCalls, 1); compare(notices.entries.length, 0);
            networkBackend.wifiEnabled = false; networkBackend.radioConfirmed();
            verify(!wifi.checked); compare(wifi.text, "Wi-Fi");
            bluetoothBackend.automatic = false;
            bt.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            verify(bluetooth.busy); verify(bt.checked); compare(bt.text, "Bluetooth");
            bluetoothBackend.settle(bluetoothBackend.operation, true, "");
            verify(!bt.checked); compare(notices.entries.length, 0);
            compare(preview.coordinator.activeId, "quickSettings");
            compare(network.scanRequests, 0); compare(bluetoothBackend.managerCalls, 0);
            verify(!preview.osd.visible);
        }
        function test_error_is_only_a_notification() {
            open(); notices.dnd = true;
            const height = preview.panelHost.window.height;
            audioBackend.rejectWrites = true;
            keyClick(Qt.Key_L);
            compare(notices.entries.length, 1); verify(notices.entries[0].critical);
            compare(notices.entries[0].summary, "Dźwięk");
            compare(preview.panelHost.window.height, height);
            compare(control("audioError"), null); verify(!preview.osd.visible);
        }
        function test_radio_modules_own_lists_and_scanning() {
            mouseClick(preview.bar.networkButton);
            tryCompare(preview.coordinator, "activeId", "network");
            tryCompare(preview.panelHost, "loaded", true);
            tryCompare(networkBackend.wifi, "scannerEnabled", true);
            verify(control("wifiNetwork-0-2") !== null);
            preview.coordinator.close(false); tryCompare(preview.panelHost, "loaded", false);
            compare(network.scanRequests, 0);
            mouseClick(preview.bar.bluetoothButton);
            tryCompare(preview.coordinator, "activeId", "bluetooth");
            tryCompare(preview.panelHost, "loaded", true);
            verify(control("bluetoothDevice-0") !== null);
            compare(bluetoothBackend.internal.discoveryChanges, 0);
        }
        function test_night_light_temperature_has_no_refresh() {
            open();
            control("nightLightToggle").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_J);
            verify(control("nightLightTemperature").activeFocus);
            const value = night.temperature;
            keyClick(Qt.Key_H); tryCompare(night, "temperature", value - 100);
            keyClick(Qt.Key_J); verify(control("lockButton").activeFocus);
            keyClick(Qt.Key_K); verify(control("nightLightTemperature").activeFocus);
            control("nightLightToggle").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            tryCompare(night, "enabled", false); verify(!control("nightLightTemperature").visible);
            compare(control("nightLightRefresh"), null); compare(control("nightLightExpand"), null);
            keyClick(Qt.Key_Return); tryCompare(night, "enabled", true);
            verify(control("nightLightTemperature").visible);
            verify(control("nightLightTemperatureIcon").visible);
        }
        function test_notification_center_empty_and_mouse_focus() {
            open();
            preview.coordinator.close(false); tryCompare(preview.panelHost, "loaded", false);
            mouseClick(findChild(preview.bar, "barNotifications"));
            tryCompare(preview.coordinator, "activeId", "notifications");
            tryVerify(() => control("notificationDnd").activeFocus);
            tryCompare(preview.panelHost.window, "opacity", 1);
            verify(waitForPolish(scene));
            compare(rings(preview.panelHost.window).length, 0);
            keyClick(Qt.Key_Return); verify(notices.dnd); compare(rings(preview.panelHost.window).length, 1);
            mouseClick(control("notificationDnd")); verify(!notices.dnd); compare(rings(preview.panelHost.window).length, 0);
            compare(preview.panelHost.window.page.cards.count, 0);
        }
        function test_history_keeps_expired_dnd_and_transient() {
            const id = notificationBackend.send({summary: "Krótki", expireTimeout: 30, actions: [["open", "Otwórz"]]});
            tryVerify(() => notices.find(id) === null);
            compare(notices.history.length, 1); compare(notices.history[0].actions.length, 0);
            compare(notices.history[0].imageSource, "");
            notices.dnd = true;
            notificationBackend.send({summary: "Wyciszone", expireTimeout: 0});
            compare(notices.entries.length, 0); compare(notices.history.length, 2);
            notificationBackend.send({summary: "Przejściowe", transient: true});
            compare(notices.history.length, 3);
            open("notifications");
            compare(preview.panelHost.window.page.cards.count, 3);
            keyClick(Qt.Key_J); verify(preview.panelHost.window.page.cardAt(0).selectionControl.activeFocus);
            keyClick(Qt.Key_L); verify(preview.panelHost.window.page.cardAt(0).closeControl.activeFocus);
            keyClick(Qt.Key_Return); compare(notices.history.length, 2);
            control("notificationClear").forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            compare(notices.history.length, 0); compare(preview.panelHost.window.page.cards.count, 0);
        }
        function test_history_replacements_limit_and_live_actions() {
            const id = notificationBackend.send({summary: "Pierwszy", expireTimeout: 0, actions: [["open", "Otwórz"]], resident: true});
            notificationBackend.send({replacesId: id, summary: "Zmieniony", expireTimeout: 0, actions: [["open", "Pokaż"]], resident: true});
            wait(20); compare(notices.history.length, 1); compare(notices.history[0].summary, "Zmieniony");
            open("notifications");
            const card = preview.panelHost.window.page.cardAt(0);
            compare(card.actionAt(0).text, "Pokaż");
            card.closeControl.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            compare(notificationBackend.actionEvents.length, 1);
            compare(preview.coordinator.activeId, "");
            notices.dnd = true;
            for (let i = 0; i < 110; ++i) notificationBackend.send({summary: "Pozycja " + i});
            compare(notices.history.length, 100); compare(notices.history[0].summary, "Pozycja 109");
            verify(notices.history.every(value => value.actions.length === 0 && value.imageSource === ""));
            notices.clear(); compare(notices.history.length, 0);
        }
        function test_center_mouse_dismiss_and_expired_action_recover_focus() {
            const id = notificationBackend.send({summary: "Akcja", expireTimeout: 0, actions: [["open", "Otwórz"]]});
            open("notifications");
            let card = preview.panelHost.window.page.cardAt(0);
            card.actionAt(0).forceActiveFocus(Qt.TabFocusReason);
            notices.expire(notices.find(id));
            tryVerify(() => control("notificationDnd").activeFocus);
            compare(preview.panelHost.window.page.cardAt(0).actionItems.count, 0);
            verify(waitForPolish(scene));
            mouseClick(preview.panelHost.window.page.cardAt(0).closeControl);
            tryCompare(preview.panelHost.window.page.cards, "count", 0);
            wait(20); compare(rings(preview.panelHost.window).length, 0);
        }
        function test_center_small_panel_and_lifecycles() {
            scene.width = 320; scene.height = 220;
            notices.dnd = true;
            for (let i = 0; i < 5; ++i) notificationBackend.send({summary: "Pozycja " + i, body: "Treść ".repeat(200)});
            for (let i = 0; i < 10; ++i) {
                open("notifications");
                const page = preview.panelHost.window.page;
                const last = page.cardAt(4).closeControl;
                last.forceActiveFocus(Qt.TabFocusReason);
                wait(20);
                const pos = last.mapToItem(preview.panelHost.window.viewport, 0, 0);
                verify(pos.y >= 0 && pos.y + last.height <= preview.panelHost.window.viewport.height);
                keyClick(Qt.Key_Escape); tryCompare(preview.panelHost, "loaded", false);
                compare(preview.createdCount, preview.destroyedCount);
            }
        }
    }
}
