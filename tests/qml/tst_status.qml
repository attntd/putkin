import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/tray"
import "IconPixels.js" as Pixels

Item {
    id: scene
    width: 1366; height: 768
    MockBatteryBackend { id: backend }
    BatteryService { id: battery; backend: backend }
    MockPowerProfileBackend { id: profileBackend }
    PowerProfileService { id: profiles; backend: profileBackend }
    MockTray { id: tray }
    Component {
        id: iconButtonFixture
        TrayButton {
            x: 20; y: 60
            width: Metrics.trayButtonWidth; height: Metrics.barHeight
            onPrimaryRequested: trayItem.activate()
        }
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
        battery: battery
        powerProfiles: profiles
        tray: tray
        trayMenuComponent: tray.menuComponent
    }
    TestCase {
        name: "BatteryTray"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
            preview.barController.close();
            preview.settings.cancelEdit();
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            tray.reset(16);
            backend.available = true;
            backend.device = backend.battery;
            backend.battery.ready = true; backend.battery.isPresent = true;
            backend.battery.isLaptopBattery = true; backend.battery.percentage = 0.72;
            backend.battery.state = 2; backend.battery.timeToEmpty = 14400;
            backend.battery.timeToFull = 0;
            profileBackend.available = true;
            profileBackend.profile = "balanced";
            profileBackend.profiles = ["power-saver", "balanced", "performance"];
            profileBackend.pendingProfile = "";
            profileBackend.degradationReason = "";
            profileBackend.lastError = "";
            profileBackend.calls = 0;
            profileBackend.autoComplete = true;
            scene.width = 1366; scene.height = 768;
            mouseMove(scene, 200, 600);
            wait(20);
        }
        function cleanup() {
            preview.coordinator.close(false);
            tryCompare(preview.panelHost, "loaded", false);
        }
        function control(name) { return findChild(preview.panelHost.window, name); }
        function app(index) { return findChild(preview.bar, "tray-app" + index); }
        function page() { return preview.panelHost.window.page; }
        function menu(index) { return findChild(page().currentLevel, "trayMenuEntry-" + index); }
        function test_battery_material_states_data() {
            return [
                {tag: "empty", level: 0, state: 2, icon: "battery_android_0"},
                {tag: "one", level: 0.1, state: 2, icon: "battery_android_1"},
                {tag: "two", level: 0.25, state: 2, icon: "battery_android_2"},
                {tag: "three", level: 0.4, state: 2, icon: "battery_android_3"},
                {tag: "four", level: 0.55, state: 2, icon: "battery_android_4"},
                {tag: "five", level: 0.7, state: 2, icon: "battery_android_5"},
                {tag: "six", level: 0.85, state: 2, icon: "battery_android_6"},
                {tag: "full", level: 1, state: 4, icon: "battery_android_full"},
                {tag: "unknown", level: -1, state: 0, icon: "battery_android_question"},
                {tag: "charging20", level: 0.2, state: 1, icon: "battery_charging_20_2"},
                {tag: "charging30", level: 0.3, state: 1, icon: "battery_charging_30_2"},
                {tag: "charging50", level: 0.5, state: 1, icon: "battery_charging_50_2"},
                {tag: "charging60", level: 0.6, state: 1, icon: "battery_charging_60_2"},
                {tag: "charging80", level: 0.8, state: 1, icon: "battery_charging_80_2"},
                {tag: "chargingFull", level: 1, state: 1, icon: "battery_charging_full_2"}
            ];
        }
        function test_battery_material_states(data) {
            backend.battery.percentage = data.level; backend.battery.state = data.state;
            const icon = findChild(preview.bar.batteryButton, "batteryIcon");
            compare(icon.symbol, data.icon);
            compare(icon.iconSize, 20); compare(icon.iconPadding, 6);
            compare(icon.width, data.state === 1 ? 36 : 32); compare(icon.height, 30);
        }
        function test_tray_icon_center_and_signal_color_data() {
            return [{tag: "signal", title: "Signal", itemId: "app0", symbol: "chat_bubble"},
                {tag: "signalId", title: "", itemId: "Signal_status_icon_1", symbol: "chat_bubble"},
                {tag: "tether", title: "Tether", itemId: "app0", symbol: "putkin_tether"},
                {tag: "unknown", title: "Other application", itemId: "app0", symbol: "apps"}];
        }
        function test_tray_icon_center_and_signal_color(data) {
            tray.reset(1);
            const item = tray.items.values[0];
            item.objectName = data.itemId; item.title = data.title;
            item.icon = Qt.resolvedUrl("../fixtures/launcher-icon.svg").toString();
            const button = createTemporaryObject(iconButtonFixture, scene, {trayItem: item});
            verify(button !== null);
            const icon = findChild(button, "trayApplicationIcon");
            compare(icon.symbol, data.symbol);
            compare(icon.iconSize, 20); compare(icon.iconPadding, 6);
            const center = icon.mapToItem(button, icon.width / 2, icon.height / 2);
            compare(center.x, button.width / 2); compare(center.y, button.height / 2);
            Pixels.verifyIcon(this, scene, icon, button.fillColor);
            item.icon = "";
            compare(icon.symbol, data.symbol);
            mouseClick(button); compare(item.activations, 1);
        }
        function test_signal_unread_icon_updates_data() {
            return [{tag: "bar", labeled: false}, {tag: "overflow", labeled: true}];
        }
        function test_signal_unread_icon_updates(data) {
            tray.reset(1);
            const item = tray.items.values[0];
            item.objectName = "Signal_status_icon_1";
            item.title = "";
            item.status = 1; // Electron keeps Active, even with unread messages.
            item.icon = Qt.resolvedUrl("../fixtures/signal-tray-read.svg").toString();
            const button = createTemporaryObject(iconButtonFixture, scene, {trayItem: item, showLabel: data.labeled,
                width: data.labeled ? 300 : 32, height: data.labeled ? 36 : 30});
            verify(button !== null);
            const icon = findChild(button, "trayApplicationIcon");
            const dot = findChild(button, "trayAttentionDot");
            tryCompare(icon, "symbol", "chat_bubble");
            button.forceActiveFocus(Qt.TabFocusReason);
            const original = [icon.width, icon.height, icon.x, icon.y, icon.color];
            for (let i = 0; i < 2; ++i) {
                item.icon = Qt.resolvedUrl("../fixtures/signal-tray-unread.svg").toString();
                tryCompare(icon, "symbol", "chat");
                compare(item.status, 1); verify(button.activeFocus); verify(!dot.visible);
                compare([icon.width, icon.height, icon.x, icon.y, icon.color], original);
                // The surrounding keyboard focus frame has the accent gradient.
                Pixels.verifyIcon(this, scene, icon, button.fillColor, findChild(icon, "iconCanvas"));
                item.icon = Qt.resolvedUrl("../fixtures/signal-tray-read.svg").toString();
                tryCompare(icon, "symbol", "chat_bubble");
                verify(button.activeFocus);
                compare([icon.width, icon.height, icon.x, icon.y, icon.color], original);
            }
            item.icon = ""; item.status = 2;
            tryCompare(icon, "symbol", "chat"); verify(!dot.visible);
            item.status = 1;
            tryCompare(icon, "symbol", "chat_bubble");
            item.icon = Qt.resolvedUrl("../fixtures/signal-tray-unread.svg").toString();
            tryCompare(icon, "symbol", "chat");
            item.objectName = "other";
            tryCompare(icon, "symbol", "apps");
            item.status = 2;
            verify(dot.visible); // Other applications keep their existing indicator.
            keyClick(Qt.Key_Return); compare(item.activations, 1);
        }
        function openMenu(index) {
            verify(preview.coordinator.openTray(tray.items.values[index || 0], preview.firstScreen, app(index || 0)));
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => page().depth === 1 && menu(0) && menu(0).activeFocus);
        }
        function test_battery_states_data() {
            return [
                {tag: "charging", state: 1, text: "Ładowanie", time: "do pełna: 1 h 5 min"},
                {tag: "discharging", state: 2, text: "Na baterii", time: "pozostało: 4 h 0 min"},
                {tag: "full", state: 4, text: "Naładowana", time: ""},
                {tag: "unknown", state: 0, text: "Stan baterii nieznany", time: ""},
                {tag: "empty", state: 3, text: "Rozładowana", time: ""},
                {tag: "pendingCharge", state: 5, text: "Oczekuje na ładowanie", time: ""},
                {tag: "pendingDischarge", state: 6, text: "Oczekuje na rozładowanie", time: ""}
            ];
        }
        function test_battery_states(data) {
            backend.battery.state = data.state;
            backend.battery.timeToFull = 3900;
            compare(battery.stateText, data.text); compare(battery.timeText, data.time);
            compare(battery.percentage, 72);
            verify(preview.bar.batteryButton.visible);
            mouseClick(preview.bar.batteryButton);
            tryCompare(preview.panelHost, "loaded", true);
            compare(preview.coordinator.activeId, "battery");
            compare(control("batteryPercentage").text, "72%");
            compare(control("batteryLevel").value, 72);
            if (data.time) compare(control("batteryTime").text, data.time);
            compare(preview.bar.batteryButton.Accessible.name, battery.statusText);
            compare(preview.bar.batteryButton.width, data.state === 1 ? 36 : Metrics.barStatusReserve);
        }
        function test_absent_peripheral_unavailable_and_return() {
            backend.battery.isLaptopBattery = false;
            verify(!battery.present); verify(!preview.bar.batteryButton.visible);
            backend.battery.isLaptopBattery = true;
            backend.battery.isPresent = false;
            verify(!battery.present);
            backend.battery.isPresent = true; backend.battery.ready = false;
            verify(!battery.present);
            backend.battery.ready = true; backend.available = false;
            verify(!battery.present); compare(battery.percentage, -1);
            backend.available = true; verify(battery.present); compare(battery.percentage, 72);
            backend.device = null; verify(!battery.present);
        }
        function openBattery() {
            verify(preview.coordinator.open("battery", preview.firstScreen, preview.bar.batteryButton));
            tryCompare(preview.panelHost, "loaded", true);
            tryCompare(preview.panelHost.window, "opacity", 1);
            tryVerify(() => control("batteryProfile-balanced").activeFocus);
        }
        function test_battery_profile_keyboard_confirmed_state_and_refusal() {
            openBattery();
            const balanced = control("batteryProfile-balanced");
            const saver = control("batteryProfile-power-saver");
            const performance = control("batteryProfile-performance");
            profileBackend.autoComplete = false;
            keyClick(Qt.Key_J); verify(performance.activeFocus);
            keyClick(Qt.Key_Return);
            verify(balanced.checked); verify(!performance.checked);
            compare(profileBackend.pendingProfile, "performance");
            compare(performance.Accessible.description, "Zmiana…");
            keyClick(Qt.Key_Return); compare(profileBackend.calls, 1);
            profileBackend.complete(false);
            verify(balanced.checked); verify(!performance.checked);
            keyClick(Qt.Key_K); keyClick(Qt.Key_K); verify(saver.activeFocus);
            keyClick(Qt.Key_Enter); compare(profileBackend.calls, 2);
            profileBackend.complete(true);
            verify(saver.checked); compare(profiles.profile, "power-saver");
            verify(saver.activeFocus);
            keyClick(Qt.Key_Escape);
            tryCompare(preview.panelHost, "loaded", false);
        }
        function test_battery_missing_profiles_and_focus_recovery() {
            openBattery();
            keyClick(Qt.Key_J);
            verify(control("batteryProfile-performance").activeFocus);
            profileBackend.profiles = ["power-saver", "balanced"];
            tryVerify(() => control("batteryProfile-balanced").activeFocus);
            verify(!control("batteryProfile-performance").enabled);
            keyClick(Qt.Key_J); verify(control("batteryProfile-power-saver").activeFocus);
            keyClick(Qt.Key_J); verify(control("batteryProfile-balanced").activeFocus);
            keyClick(Qt.Key_J); verify(control("batteryProfile-power-saver").activeFocus);
            profileBackend.available = false;
            verify(!control("batteryProfile-balanced").checked);
            verify(!control("batteryProfile-balanced").enabled);
            tryVerify(() => page().activeFocus);
            compare(control("batteryPercentage").text, "72%");
            profileBackend.available = true;
            profileBackend.profile = "power-saver";
            verify(control("batteryProfile-power-saver").checked);
            keyClick(Qt.Key_Escape);
            tryCompare(preview.panelHost, "loaded", false);
        }
        function test_battery_unknown_time_absent_and_full() {
            openBattery();
            backend.battery.timeToEmpty = 0;
            compare(control("batteryTime").text, "Szacowanie czasu…");
            backend.battery.state = 1;
            backend.battery.timeToFull = 7500;
            compare(control("batteryTime").text, "do pełna: 2 h 5 min");
            backend.battery.state = 4;
            verify(!control("batteryTime").visible);
            backend.battery.isPresent = false;
            compare(control("batteryPercentage").text, "—");
            verify(!control("batteryLevel").visible);
            verify(control("batteryProfile-balanced").enabled);
        }
        function test_battery_small_screen_scroll_and_mouse() {
            scene.width = 320; scene.height = 220;
            openBattery();
            verify(preview.panelHost.window.height <= 180);
            verify(preview.panelHost.window.viewport.contentY > 0);
            keyClick(Qt.Key_J);
            const performance = control("batteryProfile-performance");
            verify(performance.activeFocus);
            waitForPolish(scene); waitForRendering(scene);
            const pos = performance.mapToItem(preview.panelHost.window, 0, 0);
            verify(pos.y >= 0 && pos.y + performance.height <= preview.panelHost.window.height);
            mouseClick(performance);
            compare(profiles.profile, "performance");
            keyClick(Qt.Key_J); verify(control("batteryProfile-power-saver").activeFocus);
            keyClick(Qt.Key_Escape); tryCompare(preview.panelHost, "loaded", false);
        }
        function test_battery_monitor_toggle_and_twenty_cycles() {
            preview.barController.focusBar();
            preview.bar.batteryButton.forceActiveFocus();
            keyClick(Qt.Key_Return);
            tryCompare(preview.panelHost, "loaded", true);
            compare(preview.coordinator.activeId, "battery");
            compare(preview.coordinator.screenName, "TEST-1");
            tryCompare(preview.panelHost.window, "opacity", 1);
            keyClick(Qt.Key_Escape);
            tryCompare(preview.panelHost, "loaded", false);
            tryVerify(() => preview.bar.batteryButton.activeFocus);
            for (let i = 0; i < 20; ++i) {
                preview.coordinator.open("battery", preview.secondScreen, null);
                tryCompare(preview.panelHost, "loaded", true);
                compare(preview.coordinator.screenName, "TEST-2");
                preview.coordinator.toggle("battery", preview.secondScreen, null);
                tryCompare(preview.panelHost, "loaded", false);
            }
            compare(preview.createdCount, preview.destroyedCount);
            preview.coordinator.open("battery", preview.secondScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            preview.coordinator.screens = [preview.firstScreen];
            tryCompare(preview.panelHost, "loaded", false);
        }
        function test_invalid_percent_unknown_time_and_warning_keeps_semantics() {
            for (const value of [-0.1, 1.01, NaN, Infinity]) {
                backend.battery.percentage = value; compare(battery.percentage, -1); compare(battery.warningLevel, 0);
            }
            backend.battery.percentage = 0; compare(battery.percentage, 0); compare(battery.warningLevel, 2);
            compare(findChild(preview.bar.batteryButton, "batteryIcon").color, Theme.text);
            backend.battery.percentage = 0.12; compare(battery.warningLevel, 1);
            verify(battery.statusText.indexOf("Niski poziom") >= 0);
            preview.settings.beginEdit(); preview.settings.setColor("accent", "#000000");
            compare(findChild(preview.bar.batteryButton, "batteryIcon").color, Theme.text);
            backend.battery.state = 1; compare(battery.warningLevel, 0);
            for (const seconds of [0, -2, NaN, Infinity]) { backend.battery.timeToFull = seconds; compare(battery.timeText, ""); }
            backend.battery.timeToFull = 30; compare(battery.timeText, "do pełna: 1 min");
        }
        function test_bar_activation_secondary_menu_tooltip_fallback() {
            const first = app(0);
            verify(first.Accessible.name.length > 0);
            compare(findChild(first, "trayApplicationIcon").symbol, "apps");
            mouseMove(first, 10, 10);
            wait(650); compare(findChild(first, "tooltip"), null);
            mouseClick(first); compare(tray.items.values[0].activations, 1);
            mouseClick(first, 10, 10, Qt.MiddleButton); compare(tray.items.values[0].secondaryActivations, 1);
            mouseClick(first, 10, 10, Qt.RightButton);
            tryCompare(preview.coordinator, "activeId", "trayMenu");
            tryCompare(preview.panelHost, "loaded", true);
            compare(tray.items.values[0].activations, 1);
        }
        function test_bar_keyboard_and_only_menu() {
            preview.barController.focusBar();
            preview.bar.workspaces.selectIndex(preview.bar.workspaces.service.workspaces.count - 1, true);
            wait(20);
            keyClick(Qt.Key_L); verify(app(0).activeFocus);
            keyClick(Qt.Key_Return); compare(tray.items.values[0].activations, 1);
            app(0).forceActiveFocus(); keyClick(Qt.Key_Return, Qt.ShiftModifier);
            compare(tray.items.values[0].secondaryActivations, 1);
            keyClick(Qt.Key_L); verify(app(1).activeFocus);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier);
            tryCompare(preview.coordinator, "activeId", "trayMenu");
            compare(tray.items.values[1].activations, 0);
        }
        function test_menu_vim_standard_keys_submenu_and_trigger() {
            openMenu(0);
            keyClick(Qt.Key_J); verify(menu(3).activeFocus); // disabled + separator skipped
            keyClick(Qt.Key_L); tryCompare(page(), "depth", 2);
            tryVerify(() => menu(0).activeFocus);
            keyClick(Qt.Key_H); tryCompare(page(), "depth", 1);
            tryVerify(() => menu(3).activeFocus);
            keyClick(Qt.Key_Return); tryCompare(page(), "depth", 2);
            tryVerify(() => menu(0).activeFocus);
            keyClick(Qt.Key_Escape); tryCompare(page(), "depth", 1);
            keyClick(Qt.Key_Up); verify(menu(0).activeFocus);
            keyClick(Qt.Key_Tab); verify(menu(3).activeFocus);
            keyClick(Qt.Key_Backtab); verify(menu(0).activeFocus);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier);
            compare(tray.openEntry.activations, 1);
            tryCompare(preview.panelHost, "loaded", false);
        }
        function test_menu_icon_updates_keep_vector_size_and_action() {
            openMenu(0);
            tryCompare(preview.panelHost.window, "opacity", 1);
            const icon = findChild(menu(0), "trayMenuIcon");
            try {
                for (const pair of [["document-open", "open_in_new"], ["preferences-system", "settings"],
                        ["/no/colored.png", "apps"], ["", ""]]) {
                    tray.openEntry.icon = pair[0];
                    compare(icon.symbol, pair[1]);
                    compare(icon.width, 28); compare(icon.height, 28);
                    compare(icon.iconSize, 20); compare(icon.iconPadding, 4);
                    verify(icon.visible);
                    compare(icon.mapToItem(menu(0), 0, icon.height / 2).y, menu(0).height / 2);
                }
                keyClick(Qt.Key_Return);
                compare(tray.openEntry.activations, 1);
                tryCompare(preview.panelHost, "loaded", false);
            } finally { tray.openEntry.icon = ""; }
        }
        function test_surface_exclusion_settings_cancel_and_monitor() {
            preview.coordinator.open("settings", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            preview.settings.setColor("accent", "#94e2d5");
            openMenu(0);
            verify(!preview.settings.editing);
            const count = preview.createdCount;
            keyClick(Qt.Key_J); keyClick(Qt.Key_L);
            tryCompare(page(), "depth", 2);
            compare(preview.createdCount, count); // same family, same surface
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryVerify(() => control("settingsButton") && control("settingsButton").activeFocus);
            preview.coordinator.openTray(tray.items.values[0], preview.secondScreen, null);
            tryCompare(preview.panelHost, "screen", preview.secondScreen);
            preview.coordinator.screens = [preview.firstScreen];
            tryCompare(preview.panelHost, "loaded", false);
        }
        function test_overflow_all_items_scrolling_back_and_escape_restore_data() {
            return [{tag: "escape", key: Qt.Key_Escape}, {tag: "q", key: Qt.Key_Q}];
        }
        function test_overflow_all_items_scrolling_back_and_escape_restore(data) {
            scene.width = 320; scene.height = 220;
            preview.barController.focusBar();
            preview.bar.trayStrip.lastControl.forceActiveFocus();
            keyClick(Qt.Key_Return);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("trayApp-app0").activeFocus);
            for (let i = 0; i < 15; ++i) keyClick(Qt.Key_J);
            verify(control("trayApp-app15").activeFocus);
            verify(preview.panelHost.window.viewport.contentY > 0);
            keyClick(Qt.Key_L); verify(control("trayAppMenu-app15").activeFocus);
            keyClick(Qt.Key_Return);
            tryVerify(() => page().showingMenu && page().depth === 1);
            keyClick(data.key);
            tryCompare(preview.coordinator, "activeId", "trayOverflow");
            keyClick(data.key);
            tryCompare(preview.panelHost, "loaded", false);
            tryVerify(() => preview.bar.trayStrip.lastControl.activeFocus);
        }
        function test_removal_with_focus_and_active_menu() {
            app(0).forceActiveFocus();
            const removed = tray.items.values[0];
            tray.items.removeObject(removed);
            tryVerify(() => preview.bar.trayStrip.lastControl.activeFocus);
            preview.coordinator.openTray(tray.items.values[0], preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tray.items.removeObject(tray.items.values[0]);
            tryCompare(preview.panelHost, "loaded", false);
            preview.coordinator.open("trayOverflow", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("trayApp-app2").activeFocus);
            tray.items.removeObject(tray.items.values[0]);
            tryVerify(() => control("trayApp-app3").activeFocus);
        }
        function test_menu_live_update_removes_submenu_and_recovers_focus() {
            openMenu(0); keyClick(Qt.Key_J); keyClick(Qt.Key_L);
            tryCompare(page(), "depth", 2);
            tray.menu.entries.removeObject(tray.sub);
            tryCompare(page(), "depth", 1);
            tryVerify(() => menu(0).activeFocus);
            tray.menu.entries.removeObject(tray.openEntry);
            tryVerify(() => menu(2).activeFocus);
        }
        function test_layouts_preserve_main_controls() {
            for (const width of [1920, 1366, 960, 683, 600, 480, 320]) {
                scene.width = width; wait(10);
                const bar = preview.bar;
                verify(bar.trayStrip.width <= 5 * Metrics.trayButtonWidth);
                verify(bar.workspaces.x + bar.workspaces.width <= bar.trayStrip.mapToItem(bar, 0, 0).x);
                verify(bar.clock.mapToItem(bar, 0, 0).x + bar.clock.width <= width + 0.01);
                verify(bar.quickSettingsButton.x >= 0);
                verify(bar.workspaces.list.width >= Metrics.workspaceWidth);
                verify(bar.trayStrip.lastControl.visible);
            }
            openMenu(0);
            verify(preview.panelHost.window.x >= Metrics.panelGap);
            verify(preview.panelHost.window.x + preview.panelHost.window.width <= scene.width - Metrics.panelGap);
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            scene.width = 1366;
            wait(20);
            compare(preview.panelHost.window.x + preview.panelHost.window.width, scene.width - Metrics.panelGap);
        }
        function test_updates_do_not_take_focus_from_header_and_passive_skips() {
            preview.coordinator.open("trayOverflow", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            tryVerify(() => control("trayApp-app0").activeFocus);
            control("trayClose").forceActiveFocus();
            tray.items.removeObject(tray.items.values[0]);
            wait(20);
            verify(control("trayClose").activeFocus);
            keyClick(Qt.Key_J); verify(control("trayApp-app1").activeFocus);
            tray.items.values[0].status = 0;
            tryVerify(() => control("trayApp-app2").activeFocus);
            control("trayApp-app3").forceActiveFocus();
            keyClick(Qt.Key_Menu);
            tryVerify(() => page().depth === 1 && menu(0).activeFocus);
            control("trayBack").forceActiveFocus();
            tray.menu.entries.removeObject(tray.openEntry);
            wait(20);
            verify(control("trayBack").activeFocus);
        }
        function test_return_after_invoker_removed_and_keyboard_context_menu() {
            preview.barController.focusBar();
            wait(20);
            app(0).forceActiveFocus();
            keyClick(Qt.Key_F10, Qt.ShiftModifier);
            tryCompare(preview.panelHost, "loaded", true);
            const removed = tray.items.values[0];
            tray.items.removeObject(removed);
            removed.destroy();
            tryCompare(preview.panelHost, "loaded", false);
            tryVerify(() => preview.bar.quickSettingsButton.activeFocus);
        }
    }
}
