import QtQuick
import QtQuick.Controls.Basic as Controls
import QtTest
import "../../core"
import "../../preview"
import "../../services"

Item {
    id: scene
    width: 1000
    height: 700
    // QtTest cannot load Quickshell's executable-only plugin. The same host
    // receives Qt's Item loader here; real LazyLoader is tested through IPC.
    QtObject {
        id: testLoader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader {
            active: testLoader.activeAsync
            asynchronous: true
            sourceComponent: preview.panelComponent
        }
    }
    MockAudioBackend { id: audioBackend }
    AudioService { id: audioModel; backend: audioBackend }
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: testLoader }
    Component { id: textEditor; Controls.TextField { width: 200 } }

    TestCase {
        id: tests
        name: "Panels"
        when: windowShown
        readonly property var coordinator: preview.coordinator
        readonly property var host: preview.panelHost

        function init() {
            failOnWarning(/.*/);
            coordinator.close(false);
            tryCompare(host, "loaded", false);
            preview.barController.close();
            preview.backend.reset();
            preview.audio = null;
            audioBackend.reset();
            coordinator.screens = [preview.firstScreen, preview.secondScreen];
            scene.width = 1000;
            scene.height = 700;
            mouseMove(scene, 100, 650);
        }

        function cleanup() {
            coordinator.close(false);
            tryCompare(host, "loaded", false);
            tryCompare(preview, "destroyedCount", preview.createdCount);
        }

        function open(id = "quickSettings") {
            verify(coordinator.open(id, preview.firstScreen, null));
            tryCompare(host, "loaded", true);
            tryVerify(() => host.window.page !== null);
            tryVerify(() => (id === "settings" ? button("backButton") : host.window.page.firstControl).activeFocus);
            return host.window;
        }

        function button(name) { return findChild(host.window, name); }

        function test_reject_unknown_surface_and_missing_screen() {
            verify(!coordinator.open("unknown", preview.firstScreen, null));
            compare(coordinator.lastError, "unknown-surface");
            compare(coordinator.activeId, "");
            verify(!host.loaded);
            open();
            const session = coordinator.session;
            verify(!coordinator.open("nonexistent", preview.firstScreen, null));
            compare(coordinator.session, session);
            verify(!coordinator.open("settings", nullScreen, null));
            compare(coordinator.lastError, "screen-unavailable");
            compare(coordinator.session, session);
            coordinator.screens = [];
            compare(coordinator.activeId, "");
            verify(!coordinator.open("settings", null, null));
            compare(coordinator.lastError, "screen-unavailable");
        }
        readonly property QtObject nullScreen: QtObject { readonly property string name: "missing" }

        function test_mouse_active_indicator_tooltip_and_outside_consumption() {
            const trigger = preview.bar.quickSettingsButton;
            mouseMove(trigger, trigger.width / 2, trigger.height / 2);
            wait(650);
            compare(findChild(trigger, "tooltip"), null);
            compare(trigger.Accessible.name, "Szybkie ustawienia");
            mouseClick(trigger);
            tryCompare(host, "loaded", true);
            tryVerify(() => button("settingsButton").activeFocus);
            verify(trigger.highlighted);
            compare((trigger.background as Rectangle).color, Theme.accent);
            const clicks = preview.desktopClicks;
            mouseClick(scene, 20, 400);
            compare(coordinator.activeId, "");
            verify(!host.interactive);
            verify(!trigger.highlighted);
            compare(preview.desktopClicks, clicks);
            compare(preview.barController.screenName, "");
        }

        function test_directions_enter_keypad_space_and_escape_layers() {
            preview.audio = audioModel;
            open();
            verify(button("audioVolume").activeFocus);
            keyClick(Qt.Key_Return);
            verify(host.window.page.audioSection.expanded);
            keyClick(Qt.Key_Escape);
            verify(!host.window.page.audioSection.expanded);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier);
            verify(host.window.page.audioSection.expanded);
            keyClick(Qt.Key_I);
            verify(!host.window.page.audioSection.expanded);
            button("settingsButton").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            tryVerify(() => button("backButton") && button("backButton").activeFocus);
            keyClick(Qt.Key_L); verify(button("closeButton").activeFocus);
            keyClick(Qt.Key_H); verify(button("backButton").activeFocus);
            keyClick(Qt.Key_J); verify(button("appearanceSection").activeFocus);
            keyClick(Qt.Key_J); verify(button("accentPreset0").activeFocus);
            keyClick(Qt.Key_K); verify(button("appearanceSection").activeFocus);
            keyClick(Qt.Key_K); verify(button("backButton").activeFocus);
            keyClick(Qt.Key_Escape);
            compare(coordinator.activeId, "");
        }

        function test_disabled_tab_arrows_and_text_editing() {
            open("settings");
            const first = button("accentPreset0");
            const middle = button("accentPreset1");
            const last = button("accentPreset2");
            middle.enabled = false;
            first.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_L); verify(last.activeFocus);
            keyClick(Qt.Key_H); verify(first.activeFocus);
            keyClick(Qt.Key_Tab); verify(last.activeFocus);
            keyClick(Qt.Key_Backtab); verify(first.activeFocus);
            middle.enabled = true;
            keyClick(Qt.Key_Right); verify(middle.activeFocus);
            keyClick(Qt.Key_Left); verify(first.activeFocus);
            const editor = createTemporaryObject(textEditor, host.window, { y: 40 });
            editor.forceActiveFocus();
            for (const key of [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L]) keyClick(key);
            compare(editor.text, "hjkl");
            verify(editor.activeFocus);
            compare(coordinator.activeId, "settings");
            editor.destroy();
        }

        function test_settings_replaces_page_and_keeps_local_state_local() {
            preview.audio = audioModel;
            const window = open();
            button("audioOutputs").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            verify(window.page.audioSection.expanded);
            button("settingsButton").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            compare(coordinator.activeId, "settings");
            tryCompare(host, "loaded", true);
            verify(host.window !== window);
            tryVerify(() => button("backButton") && button("backButton").activeFocus);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier);
            compare(coordinator.activeId, "quickSettings");
            tryVerify(() => button("audioVolume") && button("audioVolume").activeFocus);
            verify(!host.window.page.audioSection.expanded);
        }

        function test_keyboard_bar_entry_and_return_focus() {
            preview.barController.focusBar();
            tryVerify(() => preview.bar.workspaces.list.currentItem.activeFocus);
            keyClick(Qt.Key_End);
            wait(10);
            keyClick(Qt.Key_L);
            verify(preview.bar.quickSettingsButton.activeFocus);
            keyClick(Qt.Key_Return);
            tryCompare(host, "loaded", true);
            tryVerify(() => button("settingsButton").activeFocus);
            compare(preview.barController.screenName, "");
            keyClick(Qt.Key_Escape);
            tryVerify(() => preview.bar.quickSettingsButton.activeFocus);
            compare(preview.barController.screenName, "TEST-1");
            wait(Metrics.panelFade + 30);
            verify(preview.bar.quickSettingsButton.activeFocus);
        }

        function test_twenty_cycles_and_reopen_during_fade() {
            for (let cycle = 0; cycle < 20; ++cycle) {
                const window = open();
                coordinator.close(false);
                verify(!host.interactive);
                verify(!window.enabled);
                verify(host.loaded);
                wait(20);
                open();
                compare(host.window, window);
                wait(Metrics.panelFade + 20);
                verify(host.loaded && host.interactive);
                coordinator.close(false);
                tryCompare(host, "loaded", false);
                tryCompare(preview, "destroyedCount", preview.createdCount);
            }
        }

        function test_close_before_async_load_and_switch_monitor_hotplug() {
            verify(coordinator.open("quickSettings", preview.firstScreen, null));
            coordinator.close(false);
            verify(!host.interactive);
            wait(Metrics.panelFade + 30);
            verify(!host.loaded);
            open();
            const count = preview.createdCount;
            preview.backend.focusedMonitorName = "TEST-2";
            verify(coordinator.open("settings", null, null));
            compare(coordinator.screenName, "TEST-2");
            tryCompare(host, "loaded", true);
            tryCompare(preview, "createdCount", count + 1);
            compare(preview.createdCount - preview.destroyedCount, 1);
            coordinator.screens = [preview.firstScreen];
            compare(coordinator.activeId, "");
            verify(!host.interactive);
            tryCompare(host, "loaded", false);
            verify(coordinator.open("quickSettings", null, null));
            compare(coordinator.screenName, "TEST-1");
        }

        function test_small_screen_scroll_and_visible_focus() {
            scene.width = 320;
            scene.height = 220;
            const window = open("settings");
            compare(window.width, 304);
            verify(window.x >= 0 && window.x + window.width <= scene.width);
            verify(window.y >= Metrics.barHeight && window.y + window.height <= scene.height);
            verify(window.viewport.contentHeight > window.viewport.height);
            keyClick(Qt.Key_Backtab);
            const focused = button("cancelSettingsButton");
            verify(window.viewport.contentY > 0);
            verify(focused.activeFocus);
            verify(findChild(focused, "focusIndicator").visible);
            const position = focused.mapToItem(window.viewport, 0, 0);
            verify(position.y >= 0 && position.y + focused.height <= window.viewport.height);
            for (const width of [1920, 1366, 600, 320]) {
                scene.width = width;
                wait(10);
                verify(window.width <= Metrics.settingsWidth);
                verify(window.x >= 0 && window.x + window.width <= scene.width);
            }
        }

        function test_long_content_and_resize_preserve_visible_focus() {
            const window = open("settings");
            keyClick(Qt.Key_Backtab);
            scene.width = 320;
            scene.height = 240;
            wait(30);
            const back = button("cancelSettingsButton");
            verify(back.activeFocus);
            const point = back.mapToItem(window.viewport, 0, 0);
            verify(point.y >= 0 && point.y + back.height <= window.viewport.height);
            verify(window.viewport.contentY > 0);
            // A screen without room under the bar must not acquire a panel.
            coordinator.close(false);
            scene.height = Metrics.barHeight;
            verify(!coordinator.open("settings", preview.firstScreen, null));
            compare(coordinator.lastError, "screen-too-small");
            compare(coordinator.activeId, "");
        }
    }
}
