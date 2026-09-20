import QtQuick
import QtTest
import "../../core"
import "../../components" as UI
import "../../services"
import "../../preview"

Item {
    id: scene
    width: 1366; height: 768
    MockNotificationBackend { id: backend }
    NotificationService { id: notifications; backend: backend; screens: preview.coordinator.screens; monitorService: preview.backend }
    QtObject {
        id: panelLoader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader { active: panelLoader.activeAsync; sourceComponent: preview.panelComponent }
    }
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: panelLoader; notifications: notifications }
    UI.TextField { id: desktop; x: 80; y: 360; width: 200; text: "" }
    TestCase {
        name: "Notifications"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.notificationController.close();
            preview.coordinator.close(false);
            notifications.clear();
            tryCompare(preview, "notificationStack", null);
            tryCompare(preview.panelHost, "loaded", false);
            backend.available = true; backend.errorText = "";
            notifications.dnd = false; notifications.defaultTimeout = 200;
            backend.closedEvents = []; backend.actionEvents = [];
            scene.width = 1366; scene.height = 768;
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            preview.backend.focusedMonitorName = "TEST-1";
            desktop.text = ""; desktop.forceActiveFocus();
            mouseMove(scene, 40, 400);
        }
        function cleanup() {
            preview.notificationController.close();
            preview.coordinator.close(false);
            notifications.clear();
            tryCompare(preview, "notificationStack", null);
            compare(backend.objects.length, 0);
            compare(preview.toastsCreated, preview.toastsDestroyed);
        }
        function send(options) { return backend.send(Object.assign({expireTimeout: 0}, options || {})); }
        function card(index) { return preview.notificationStack.cardAt(index || 0); }
        function waitCard() { tryVerify(() => preview.notificationStack !== null && preview.notificationStack.count > 0); }
        function closed(id, reason) { return backend.closedEvents.some(event => event.id === id && event.reason === reason); }
        function test_unread_bell_expiry_center_replacement_and_dnd() {
            const bell = findChild(preview.bar, "barNotifications").contentItem;
            compare(bell.symbol, "notifications");
            const id = send({expireTimeout: 40});
            compare(notifications.unreadCount, 1); compare(bell.symbol, "notifications_unread");
            tryCompare(notifications, "entries", []);
            compare(notifications.unreadCount, 1); compare(bell.symbol, "notifications_unread");
            notifications.dnd = true;
            compare(bell.symbol, "notifications_off");
            send({summary: "Suppressed by DND"});
            compare(notifications.unreadCount, 2);
            notifications.dnd = false;
            compare(bell.symbol, "notifications_unread");
            preview.notificationController.openCenter();
            tryCompare(preview.panelHost, "loaded", true);
            compare(notifications.unreadCount, 0); compare(bell.symbol, "notifications");
            const active = send({summary: "Visible in center"});
            compare(notifications.unreadCount, 0);
            preview.coordinator.close(false);
            backend.send({replacesId: active, summary: "New content after reading"});
            compare(notifications.unreadCount, 1); compare(bell.symbol, "notifications_unread");
            notifications.dismiss(notifications.find(active));
            compare(notifications.unreadCount, 0); compare(bell.symbol, "notifications");
            verify(closed(id, 1));
        }
        function test_missing_data_plain_text_and_limits() {
            const id = send({appName: "", summary: "", body: ""});
            waitCard();
            compare(notifications.find(id).appName, "Aplikacja"); compare(notifications.find(id).summary, "Powiadomienie");
            compare(notifications.find(id).iconName, "apps");
            backend.send({replacesId: id, summary: "<b>hjkl & tytuł</b>", body: "<img src='https://example.invalid/x'>" + "długi ".repeat(2000), actions: [["default", "<b>Otwórz</b>"]]});
            wait(30);
            compare(findChild(card(), "notificationSummary").textFormat, Text.PlainText);
            compare(findChild(card(), "notificationBody").textFormat, Text.PlainText);
            compare(card().actionAt(0).contentItem.textFormat, Text.PlainText);
            compare(notifications.find(id).body.length, 4096);
            verify(card().height <= Metrics.toastMaxHeight);
        }
        function test_arrival_mouse_close_and_action_preserve_focus() {
            const id = send({actions: [["default", "Otwórz"]]});
            waitCard(); verify(desktop.activeFocus); compare(preview.notificationController.screenName, "");
            [Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L].forEach(key => keyClick(key)); compare(desktop.text, "hjkl");
            mouseClick(card().closeControl); verify(desktop.activeFocus); verify(closed(id, 2));
            send({actions: [["default", "Otwórz"]]}); waitCard();
            mouseClick(card().actionAt(0)); verify(desktop.activeFocus); compare(backend.actionEvents.length, 1);
        }
        function test_keyboard_hjkl_enter_escape_and_tooltip() {
            const id = send({resident: true, actions: [["a", "Akcja A"], ["b", "Akcja B"], ["c", "Akcja C"], ["d", "Akcja D"]]});
            waitCard(); preview.notificationController.enter();
            tryVerify(() => card().closeControl.activeFocus);
            verify(findChild(card().closeControl, "focusIndicator").visible);
            keyClick(Qt.Key_J); verify(card().actionAt(0).activeFocus);
            keyClick(Qt.Key_L); verify(card().actionAt(1).activeFocus);
            keyClick(Qt.Key_J); verify(card().actionAt(3).activeFocus);
            keyClick(Qt.Key_H); verify(card().actionAt(2).activeFocus);
            keyClick(Qt.Key_K); verify(card().actionAt(0).activeFocus);
            keyClick(Qt.Key_Enter); compare(backend.actionEvents.length, 1); compare(backend.actionEvents[0].action, "a");
            verify(notifications.find(id) !== null); compare(preview.notificationController.screenName, "");
            preview.notificationController.enter(); tryVerify(() => card().closeControl.activeFocus);
            keyClick(Qt.Key_Tab); verify(card().actionAt(0).activeFocus);
            keyClick(Qt.Key_Backtab); verify(card().closeControl.activeFocus);
            keyClick(Qt.Key_Escape); compare(preview.notificationController.screenName, "");
            mouseMove(card().closeControl, 18, 18);
            wait(650); compare(findChild(card().closeControl, "tooltip"), null);
            compare(card().closeControl.Accessible.name, "Zamknij powiadomienie");
        }
        function test_timeout_default_zero_and_queue_deadline() {
            const normal = send({expireTimeout: -1});
            const permanent = send();
            tryVerify(() => closed(normal, 1)); verify(notifications.find(permanent) !== null);
            send(); send(); const pending = send({expireTimeout: 50});
            verify(!notifications.find(pending).shown);
            tryVerify(() => closed(pending, 1));
            compare(notifications.entries.length, 3);
        }
        function test_identical_replacement_restarts_deadline_and_retains_card() {
            const id = send({expireTimeout: 240, summary: "ten sam"}); waitCard(); const initial = card();
            wait(150);
            compare(backend.send({replacesId: id, summary: "ten sam", expireTimeout: 240}), id);
            wait(140); verify(notifications.find(id) !== null); compare(card(), initial);
            tryVerify(() => closed(id, 1));
        }
        function test_replaced_actions_and_client_close() {
            const id = send({resident: true, actions: [["a", "Stara"], ["b", "Druga"]]}); waitCard();
            backend.send({replacesId: id, actions: [["a", "Nowa"]]});
            tryCompare(card().actionAt(0), "text", "Nowa"); compare(card().actionItems.count, 1);
            verify(!notifications.invoke(notifications.find(id), "b"));
            verify(notifications.invoke(notifications.find(id), "a")); verify(notifications.find(id) !== null);
            backend.find(id).requestClose(); verify(closed(id, 3));
        }
        function test_resident_transient_and_nonresident_actions() {
            const resident = send({resident: true, actions: [["default", "Otwórz"]]});
            notifications.invoke(notifications.find(resident), "default"); verify(notifications.find(resident) !== null);
            const transient = send({transient: true, actions: [["default", "Otwórz"]]});
            notifications.invoke(notifications.find(transient), "default"); verify(closed(transient, 2));
            const timed = send({resident: true, transient: true, expireTimeout: 40});
            tryVerify(() => closed(timed, 1));
        }
        function test_dnd_discards_without_replay_and_critical_does_not_expire() {
            const first = send(); notifications.dnd = true; verify(closed(first, 1));
            for (let i = 0; i < 50; i++) send();
            compare(notifications.entries.length, 0);
            const critical = send({urgency: 2, expireTimeout: 20});
            wait(100); verify(notifications.find(critical) !== null);
            notifications.dnd = false; compare(notifications.entries.length, 1);
            notifications.dnd = true;
            backend.send({replacesId: critical, urgency: 1, expireTimeout: 0});
            tryVerify(() => closed(critical, 1));
        }
        function test_flood_bounds_fifo_and_critical_priority() {
            const ids = [];
            for (let i = 0; i < 100; i++) ids.push(send({summary: String(i)}));
            compare(notifications.entries.length, 15);
            compare(notifications.visibleOn("TEST-1").map(entry => entry.notificationId), ids.slice(0, 3));
            compare(notifications.entries.filter(entry => !entry.shown).map(entry => entry.notificationId), ids.slice(88));
            const critical = send({urgency: 2});
            verify(notifications.find(critical).shown); compare(notifications.entries.length, 15);
            notifications.dismiss(notifications.find(ids[0]));
            compare(notifications.visibleOn("TEST-1").length, 3);
        }
        function test_small_screen_bounds_images_scroll_and_queue() {
            scene.width = 320; scene.height = 220;
            const id = send({summary: "tytuł ".repeat(200), body: "treść ".repeat(2000), image: Qt.resolvedUrl("../fixtures/notification-image.svg").toString(), actions: Array.from({length: 8}, (_, i) => [String(i), "Akcja " + i])});
            for (let i = 0; i < 40; i++) send();
            compare(notifications.entries.length, 13); compare(notifications.visibleOn("TEST-1").length, 1);
            waitCard(); verify(card().height <= 172); verify(card().width <= 304);
            const picture = findChild(card(), "notificationImage");
            tryCompare(picture, "status", Image.Ready); verify(picture.sourceSize.width <= 360); verify(picture.sourceSize.height <= 100);
            preview.notificationController.enter(); tryVerify(() => card().closeControl.activeFocus);
            for (let i = 0; i < 4; i++) keyClick(Qt.Key_J);
            keyClick(Qt.Key_L); verify(card().actionAt(7).activeFocus); verify(card().viewport.contentY > 0);
            const point = card().actionAt(7).mapToItem(card(), 0, 0);
            verify(point.y >= 0 && point.y + card().actionAt(7).height <= card().height);
            keyClick(Qt.Key_Return); verify(closed(id, 2));
        }
        function test_small_screen_critical_queue_rejects_normal_before_tracking() {
            scene.width = 320; scene.height = 220;
            for (let i = 0; i < 13; i++) send({urgency: 2});
            const ordinary = send();
            compare(notifications.entries.length, 13);
            verify(closed(ordinary, 1)); verify(notifications.find(ordinary) === null);
            const critical = send({urgency: 2});
            compare(notifications.entries.length, 13); verify(notifications.find(critical) !== null);
            compare(notifications.visibleOn("TEST-1").length, 1);
        }
        function test_monitor_routing_hotplug_and_geometry() {
            const first = send();
            preview.backend.focusedMonitorName = "TEST-2"; const second = send();
            compare(notifications.find(first).monitorName, "TEST-1"); compare(notifications.find(second).monitorName, "TEST-2");
            compare(notifications.visibleOn("TEST-1").length, 1); compare(notifications.visibleOn("TEST-2").length, 1);
            preview.backend.focusedMonitorName = "TEST-1"; preview.notificationController.enter();
            preview.coordinator.screens = [preview.secondScreen];
            compare(notifications.find(first).monitorName, "TEST-2"); compare(preview.notificationController.screenName, "");
            preview.coordinator.screens = [];
            compare(notifications.entries.length, 0); verify(closed(first, 1)); verify(closed(second, 1));
            const absent = send(); verify(closed(absent, 1));
        }
        function test_screen_resize_rebalances_without_duplicate_views() {
            send(); send(); send(); waitCard(); compare(preview.notificationStack.count, 3);
            scene.height = 220;
            tryCompare(preview.notificationStack, "count", 1);
            scene.height = 768; tryCompare(preview.notificationStack, "count", 3);
        }
        function test_keyboard_pause_and_focus_repair() {
            const id = send({expireTimeout: 100}); waitCard(); preview.notificationController.enter();
            tryVerify(() => card().closeControl.activeFocus); wait(150); verify(notifications.find(id) !== null);
            const original = card(); send(); compare(card(), original); verify(card().closeControl.activeFocus);
            keyClick(Qt.Key_Return); verify(closed(id, 2));
            tryVerify(() => card().closeControl.activeFocus);
            preview.notificationController.close();
        }
        function test_quick_settings_center_dnd_and_intentional_handoff() {
            send(); waitCard();
            preview.coordinator.open("quickSettings", preview.firstScreen, null);
            tryCompare(preview, "notificationStack", null);
            tryVerify(() => findChild(preview.panelHost.window, "notificationDnd").activeFocus);
            preview.notificationController.openCenter();
            tryVerify(() => findChild(preview.panelHost.window, "notificationDnd").activeFocus);
            keyClick(Qt.Key_Return); verify(notifications.dnd); compare(notifications.entries.length, 0);
            keyClick(Qt.Key_Enter); verify(!notifications.dnd);
            send(); keyClick(Qt.Key_J); verify(preview.panelHost.window.page.cardAt(0).closeControl.activeFocus);
            keyClick(Qt.Key_Return); verify(notifications.history.length > 0);
            keyClick(Qt.Key_Escape); tryCompare(preview.panelHost, "loaded", false);
            send(); waitCard();
            preview.barController.focusBar(); compare(preview.notificationController.screenName, "");
            preview.notificationController.enter(); compare(preview.barController.screenName, "");
            preview.coordinator.open("settings", preview.firstScreen, null); compare(preview.notificationController.screenName, "");
        }
        function test_backend_loss_and_disabled_dnd() {
            const id = send(); backend.errorText = "Inny serwer"; backend.available = false;
            verify(closed(id, 1)); verify(!notifications.available);
            const rejected = send(); verify(closed(rejected, 1));
            preview.coordinator.open("notifications", preview.firstScreen, null);
            tryCompare(preview.panelHost, "loaded", true);
            verify(!findChild(preview.panelHost.window, "notificationDnd").enabled);
            compare(findChild(preview.panelHost.window, "notificationStatus"), null);
            compare(notifications.errorText, "Inny serwer");
        }
        function test_twenty_lifecycles() {
            for (let i = 0; i < 20; i++) {
                send(); waitCard();
                mouseClick(card().closeControl);
                tryCompare(preview, "notificationStack", null);
                compare(notifications.entries.length, 0);
                compare(preview.toastsCreated, preview.toastsDestroyed);
            }
        }
    }
}
