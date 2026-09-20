import QtQuick
import QtQuick.Controls.Basic as Controls
import QtTest
import "../../core"
import "../../preview"
import "../../services"
import "../../modules/bar"

Item {
    id: scene
    width: 1920
    height: 400
    MockHyprland { id: backend }
    WorkspaceService { id: service; backend: backend }
    BarFocus { id: controller; service: service; screenNames: ["TEST-1", "TEST-2"] }
    BarView {
        id: first
        width: scene.width
        height: Metrics.barHeight
        service: service
        screenName: "TEST-1"
        date: new Date(2026, 8, 16, 22, 57)
        navigating: controller.screenName === screenName
        onDismissed: controller.close()
    }
    BarView {
        id: second
        y: 80
        width: 1366
        height: Metrics.barHeight
        service: service
        screenName: "TEST-2"
        date: first.date
        navigating: controller.screenName === screenName
        onDismissed: controller.close()
    }
    Controls.TextField { id: editor; y: 200; width: 250 }

    TestCase {
        id: tests
        name: "Bar"
        when: windowShown

        function init() {
            failOnWarning(/.*/);
            controller.close();
            service.cancelAction("");
            service.actionTimeout = 2000;
            backend.reset();
            controller.screenNames = ["TEST-1", "TEST-2"];
            scene.width = 1920;
            first.clock.locale = Qt.locale("en_US");
            editor.text = "";
            editor.forceActiveFocus();
            mouseMove(scene, 800, 250);
            wait(20);
        }

        function item(view, id) {
            const index = service.indexOf(id);
            view.workspaces.list.positionViewAtIndex(index, ListView.Contain);
            view.workspaces.list.forceLayout();
            return view.workspaces.list.itemAtIndex(index);
        }

        function test_global_numbers_and_monitor_states() {
            compare(service.workspaces.count, 7);
            const ids = [];
            for (let i = 0; i < service.workspaces.count; ++i)
                ids.push(service.workspaces.get(i).workspaceId);
            compare(ids, [1, 2, 3, 4, 5, 9, 12]);
            verify(item(first, 9).activeHere);
            verify(item(second, 2).activeHere);
            verify(item(first, 2).activeElsewhere);
            verify(item(second, 9).activeElsewhere);
            compare(item(first, 12).text, "12");
            verify(item(first, 12).occupied);
            verify(item(first, 12).Accessible.name.indexOf("pilny") >= 0);
            compare(item(first, 1).text, "1");
        }

        function test_click_uses_clicked_monitor_and_swaps_visible_workspace() {
            mouseClick(item(second, 9));
            compare(backend.requests, [
                { kind: "focus", monitorName: "TEST-2" },
                { kind: "activate", workspaceId: 9, monitorName: "TEST-2" }
            ]);
            compare(service.activeId("TEST-2"), 9);
            compare(service.activeId("TEST-1"), 2);
            verify(!service.busy);
        }

        function test_vim_overflow_enter_once_and_focus() {
            backend.many();
            compare(controller.focusBar(), "TEST-1");
            tryVerify(() => first.workspaces.list.currentItem.activeFocus);
            compare(first.workspaces.selectedId, 9);
            keyClick(Qt.Key_H);
            tryCompare(first.workspaces, "selectedId", 8);
            for (let i = 8; i < 30; ++i) {
                keyClick(Qt.Key_L);
                wait(1);
            }
            compare(first.workspaces.selectedId, 30);
            const button = first.workspaces.list.currentItem;
            tryVerify(() => button.activeFocus);
            verify(findChild(button, "focusIndicator").visible);
            const position = button.mapToItem(first.workspaces.list, 0, 0);
            verify(position.x >= 0 && position.x + button.width <= first.workspaces.list.width + 1);
            compare(findChild(first, "activeWorkspace").text, "9");
            keyClick(Qt.Key_Return);
            compare(backend.requests.length, 1);
            compare(backend.requests[0].workspaceId, 30);
            compare(controller.screenName, "");
        }

        function test_keypad_enter_and_escape() {
            controller.focusBar();
            tryVerify(() => first.workspaces.list.currentItem.activeFocus);
            keyClick(Qt.Key_L);
            tryCompare(first.workspaces, "selectedId", 12);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier);
            compare(backend.requests.length, 1);
            compare(service.activeId("TEST-1"), 12);
            controller.focusBar();
            tryVerify(() => first.workspaces.list.currentItem.activeFocus);
            keyClick(Qt.Key_Escape);
            compare(controller.screenName, "");
            compare(backend.requests.length, 1);
        }

        function test_overflow_mouse_and_narrow_layout() {
            backend.many();
            for (const width of [1920, 1366, 600, 320]) {
                scene.width = width;
                wait(10);
                verify(first.workspaces.width <= Metrics.workspaceMaxWidth);
                verify(first.workspaces.x + first.workspaces.width + Metrics.barStatusReserve <= first.clock.mapToItem(first, 0, 0).x);
                verify(first.clock.width > 0 && first.clock.mapToItem(first, 0, 0).x >= 0);
                verify(findChild(first, "activeWorkspace").visible);
            }
            scene.width = 1366;
            wait(10);
            const next = findChild(first, "nextWorkspaces");
            for (let i = 0; i < 12 && next.enabled; ++i)
                mouseClick(next);
            first.workspaces.list.forceLayout();
            const last = first.workspaces.list.itemAtIndex(29);
            verify(last !== null);
            mouseClick(last);
            compare(backend.requests[0].workspaceId, 30);
        }

        function test_model_updates_preserve_delegate_and_selection() {
            controller.focusBar();
            tryVerify(() => first.workspaces.list.currentItem.activeFocus);
            const button = first.workspaces.list.currentItem;
            backend.workspaces = backend.workspaces.map(entry => ({ id: entry.id, occupied: true, urgent: false }));
            compare(first.workspaces.list.currentItem, button);
            compare(first.workspaces.selectedId, 9);
            verify(button.activeFocus);
            verify((button as WorkspaceButton).occupied);
        }

        function test_disconnect_clears_stale_state_and_keyboard_mode() {
            controller.focusBar();
            backend.connected = false;
            compare(service.available, false);
            compare(service.activeId("TEST-1"), -1);
            compare(service.workspaces.count, 5);
            compare(controller.screenName, "");
            compare(findChild(first, "unavailable"), null);
            verify(first.quickSettingsButton.visible);
            verify(!first.workspaces.visible);
            verify(!service.activate(1, "TEST-1"));
            compare(backend.requests.length, 0);
        }

        function test_action_waits_for_monitor_and_times_out() {
            backend.autoAcknowledge = false;
            service.actionTimeout = 60;
            verify(service.activate(12, "TEST-2"));
            compare(backend.requests.length, 1);
            verify(!service.activate(5, "TEST-1"));
            tryCompare(service, "busy", false);
            verify(service.lastError.length > 0);
            compare(backend.requests.length, 1);
            service.actionTimeout = 2000;
            verify(service.activate(12, "TEST-2"));
            backend.focusedMonitorName = "TEST-2";
            compare(backend.requests.length, 3);
            compare(backend.requests[2], { kind: "activate", workspaceId: 12, monitorName: "TEST-2" });
            backend.monitors = [{ name: "TEST-1", activeId: 9 }];
            verify(!service.busy);
            verify(service.lastError.length > 0);
        }

        function test_ipc_controller_fallback_and_hotplug_state() {
            backend.focusedMonitorName = "TEST-2";
            compare(controller.focusBar(), "TEST-2");
            controller.screenNames = ["TEST-1"];
            compare(controller.screenName, "");
            compare(controller.focusBar(), "TEST-1");
            controller.screenNames = [];
            compare(controller.focusBar(), "");
        }

        function test_text_input_does_not_navigate_bar() {
            editor.forceActiveFocus();
            for (const key of [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L])
                keyClick(key);
            compare(editor.text, "hjkl");
            verify(editor.activeFocus);
            compare(backend.requests.length, 0);
            compare(controller.screenName, "");
        }

        function test_locale_clock_tooltip_and_minute_change() {
            compare(first.clock.timeText.replace(/\s/g, " "), "10:57 PM");
            first.clock.locale = Qt.locale("pl_PL");
            compare(first.clock.timeText, "22:57");
            verify(first.clock.fullDate.indexOf("września") >= 0);
            const before = first.clock.label;
            first.date = new Date(2026, 8, 16, 22, 58);
            verify(first.clock.label !== before);
            mouseMove(first.clock, first.clock.width / 2, first.clock.height / 2);
            wait(650);
            compare(findChild(first.clock, "dateTooltip"), null);
            verify(first.clock.Accessible.name.indexOf(first.clock.fullDate) >= 0);
            first.date = new Date(2026, 8, 16, 22, 57);
        }
    }
}
