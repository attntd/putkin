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
    NotificationService { id: notifications; backend: backend; screens: preview.coordinator.screens; monitorService: preview.backend; applicationService: applicationService }
    NotificationApplicationService { id: applicationService; workspaceService: preview.workspaceService; applications: [signalApp.application] }
    QtObject {
        id: signalApp
        readonly property var application: ({id: "signal", name: "Signal", startupClass: "signal", execute: () => signalApp.execute()})
        property int launches: 0
        function execute(): void { launches++; }
    }
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
            applicationService.pendingApplication = null;
            applicationService.applications = [signalApp.application]; signalApp.launches = 0;
            preview.backend.reset();
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
        function openCenter() {
            preview.notificationController.openCenter();
            tryCompare(preview.panelHost, "loaded", true);
            tryCompare(preview.panelHost.window, "opacity", 1);
            verify(waitForPolish(scene));
            return preview.panelHost.window;
        }
        function test_center_header_navigation_data() {
            const cases = [];
            for (const width of [320, 1366])
                for (const arrival of ["empty", "before-open", "while-open"])
                    cases.push({tag: width + "-" + arrival, width: width, arrival: arrival});
            return cases;
        }
        function test_center_header_navigation(data) {
            scene.width = data.width;
            if (data.arrival === "before-open") { send(); send(); }
            const surface = openCenter();
            const page = surface.page;
            const dnd = findChild(page, "notificationDnd");
            const clear = findChild(page, "notificationClear");
            const heading = findChild(page, "notificationHeading");
            verify(dnd.activeFocus);
            compare(dnd.text, ""); compare(clear.text, "");
            compare(dnd.contentItem.renderedSymbol, "notifications");
            compare(clear.contentItem.renderedSymbol, "delete");
            compare(heading.y + heading.height / 2, dnd.y + dnd.height / 2);
            compare(dnd.y + dnd.height / 2, clear.y + clear.height / 2);
            verify(heading.x + heading.width <= dnd.x);
            verify(dnd.x + dnd.width <= clear.x);
            verify(clear.x + clear.width <= page.width);
            keyClick(Qt.Key_K); verify(dnd.activeFocus);
            keyClick(Qt.Key_L); verify(clear.activeFocus);
            keyClick(Qt.Key_K); verify(clear.activeFocus);
            keyClick(Qt.Key_H); verify(dnd.activeFocus);
            if (data.arrival === "while-open") { send(); send(); }
            if (data.arrival === "empty") {
                keyClick(Qt.Key_J); verify(dnd.activeFocus);
                keyClick(Qt.Key_L); keyClick(Qt.Key_J); verify(clear.activeFocus);
                keyClick(Qt.Key_Down); verify(clear.activeFocus);
                return;
            }
            const first = page.cardAt(0).selectionControl;
            const second = page.cardAt(1).selectionControl;
            keyClick(Qt.Key_J); verify(first.activeFocus);
            keyClick(Qt.Key_J); verify(second.activeFocus);
            keyClick(Qt.Key_J); verify(second.activeFocus);
            keyClick(Qt.Key_K); verify(first.activeFocus);
            keyClick(Qt.Key_K); verify(dnd.activeFocus);
            keyClick(Qt.Key_L); keyClick(Qt.Key_J); verify(first.activeFocus);
            keyClick(Qt.Key_Up); verify(dnd.activeFocus);
            keyClick(Qt.Key_Right); verify(clear.activeFocus);
            keyClick(Qt.Key_Down); verify(first.activeFocus);
        }
        function test_center_navigation_after_insert_replace_and_remove() {
            const older = send();
            const newer = send();
            const surface = openCenter();
            const page = surface.page;
            const dnd = findChild(page, "notificationDnd");
            keyClick(Qt.Key_J);
            const selected = page.cardAt(0);
            verify(selected.selectionControl.activeFocus);
            send();
            compare(page.cardAt(1), selected);
            verify(selected.selectionControl.activeFocus);
            keyClick(Qt.Key_K); verify(page.cardAt(0).selectionControl.activeFocus);
            backend.send({replacesId: older, summary: "Zaktualizowane powiadomienie"});
            compare(page.cardAt(0).entry.notificationId, older);
            dnd.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_J); verify(page.cardAt(0).selectionControl.activeFocus);
            notifications.dismissHistory(notifications.find(older).historyKey);
            tryVerify(() => dnd.activeFocus);
            keyClick(Qt.Key_J); verify(page.cardAt(0).selectionControl.activeFocus);
            keyClick(Qt.Key_J); compare(page.cardAt(1).entry.notificationId, newer);
            verify(page.cardAt(1).selectionControl.activeFocus);
        }
        function test_center_header_icon_actions() {
            send();
            const page = openCenter().page;
            const dnd = findChild(page, "notificationDnd");
            const clear = findChild(page, "notificationClear");
            keyClick(Qt.Key_Return);
            verify(notifications.dnd);
            compare(dnd.contentItem.renderedSymbol, "notifications_off");
            compare(notifications.history.length, 1);
            keyClick(Qt.Key_J); verify(page.cardAt(0).selectionControl.activeFocus);
            keyClick(Qt.Key_K); verify(dnd.activeFocus);
            mouseClick(dnd);
            verify(!notifications.dnd);
            compare(dnd.contentItem.renderedSymbol, "notifications");
            send();
            verify(waitForPolish(scene));
            mouseClick(clear);
            compare(notifications.history.length, 0);
            compare(notifications.entries.length, 0);
            tryVerify(() => dnd.activeFocus);
            keyClick(Qt.Key_J); verify(dnd.activeFocus);
            send();
            keyClick(Qt.Key_L); verify(clear.activeFocus);
            keyClick(Qt.Key_Return);
            compare(notifications.history.length, 0);
            compare(notifications.entries.length, 0);
        }
        function test_card_activation_data() {
            return [
                {tag: "enter", target: "", key: Qt.Key_Return},
                {tag: "keypad-enter", target: "", key: Qt.Key_Enter},
                {tag: "summary-click", target: "notificationSummary", key: 0},
                {tag: "body-click", target: "notificationBody", key: 0},
                {tag: "header-click", target: "header", key: 0}
            ];
        }
        function test_card_activation(data) {
            const id = send({body: "Klikalna treść", resident: true, actions: [["other", "Inna"], ["default", "Otwórz"]]});
            const surface = openCenter();
            const item = surface.page.cardAt(0);
            keyClick(Qt.Key_J); verify(item.selectionControl.activeFocus);
            if (data.key) keyClick(data.key);
            else if (data.target === "header") mouseClick(item, 70, 30);
            else mouseClick(findChild(item, data.target), 15, 8);
            compare(backend.actionEvents.length, 1);
            compare(backend.actionEvents[0].action, "default");
            compare(notifications.find(id), null);
            compare(notifications.history.length, 0);
            compare(preview.coordinator.activeId, "");
        }
        function clickCard(item, target) {
            if (target === "header") mouseClick(item, 70, 30);
            else if (target === "left-edge") mouseClick(item, 1, 50);
            else if (target === "bottom-edge") mouseClick(item, 20, item.height - 2);
            else if (target === "content-padding") mouseClick(item.viewport, 1, 8);
            else mouseClick(findChild(item, target), 15, 8);
        }
        function test_pointer_card_area_data() {
            const cases = [];
            for (const center of [false, true]) {
                for (const target of ["header", "notificationSummary", "notificationBody", "left-edge", "bottom-edge", "content-padding", "notificationImage"])
                    cases.push({tag: (center ? "center-" : "toast-") + target, center: center, target: target, longText: false});
                for (const target of ["header", "notificationBody", "content-padding"])
                    cases.push({tag: (center ? "center-long-" : "toast-long-") + target, center: center, target: target, longText: true});
            }
            return cases;
        }
        function test_pointer_card_area(data) {
            const id = send({body: data.longText ? "Długi tekst. ".repeat(150) : "Cała wiadomość",
                image: data.target === "notificationImage" ? Qt.resolvedUrl("../fixtures/notification-image.svg").toString() : "",
                resident: true, actions: [["default", "Otwórz"]]});
            waitCard();
            const item = data.center ? openCenter().page.cardAt(0) : card();
            verify(waitForPolish(scene));
            compare(item.textClipped, data.longText);
            clickCard(item, data.target);
            if (data.longText) {
                verify(item.expanded);
                compare(backend.actionEvents, []);
                verify(notifications.find(id) !== null);
                compare(notifications.history.length, 1);
                verify(waitForPolish(scene));
                clickCard(item, data.target);
            }
            compare(backend.actionEvents, [{id: id, action: "default"}]);
            compare(notifications.history.length, data.center ? 0 : 1);
            if (!data.center) verify(desktop.activeFocus);
        }
        function test_archived_signal_focuses_existing_window() {
            const id = send({appName: "Signal", actions: [["default", "Otwórz rozmowę"]]});
            notifications.expire(notifications.find(id));
            compare(notifications.history[0].applicationId, "signal");
            compare(notifications.history[0].actions, []);
            const signalWindow = {address: "0x789", workspace: {id: 12}, lastIpcObject: {class: "signal", initialClass: "signal"}};
            preview.backend.windows = preview.backend.windows.concat([signalWindow]);
            const item = openCenter().page.cardAt(0);
            clickCard(item, "content-padding");
            tryCompare(preview.backend, "activeWindow", signalWindow);
            compare(preview.workspaceService.activeId("TEST-1"), 12);
            compare(signalApp.launches, 0);
            compare(backend.actionEvents, []);
            compare(notifications.history.length, 0);
            compare(preview.coordinator.activeId, "");
        }
        function test_archived_signal_launches_then_focuses_new_window() {
            notifications.dnd = true;
            send({appName: "Signal", desktopEntry: "signal.desktop"});
            const item = openCenter().page.cardAt(0);
            clickCard(item, "header");
            tryCompare(signalApp, "launches", 1);
            compare(notifications.history.length, 0);
            const unrelated = {address: "0xabc", workspace: {id: 3}, lastIpcObject: {class: "unrelated", initialClass: "other"}};
            preview.backend.windows = [unrelated];
            wait(20); compare(preview.backend.requests, []);
            const signalWindow = {address: "0x789", workspace: {id: 12}, lastIpcObject: {class: "Signal", initialClass: "signal"}};
            preview.backend.windows = [unrelated, signalWindow];
            tryCompare(preview.backend, "activeWindow", signalWindow);
            compare(signalApp.launches, 1);
            compare(applicationService.pendingApplication, null);
        }
        function test_live_signal_keeps_native_action_and_unknown_archive_does_nothing() {
            const id = send({appName: "Signal", actions: [["default", "Otwórz rozmowę"]]});
            waitCard(); clickCard(card(), "header");
            compare(backend.actionEvents, [{id: id, action: "default"}]);
            wait(20); compare(signalApp.launches, 0); compare(preview.backend.requests, []);
            notifications.clear();
            send({appName: "Unknown", desktopEntry: "signal;false", expireTimeout: 30});
            tryCompare(notifications, "entries", []);
            const item = openCenter().page.cardAt(0);
            compare(item.entry.applicationId, "");
            clickCard(item, "header");
            compare(preview.coordinator.activeId, "notifications");
            compare(signalApp.launches, 0);
        }
        function test_kitty_default_has_no_button_data() {
            return [
                {tag: "toast-summary", center: false, target: "notificationSummary", label: " "},
                {tag: "toast-header", center: false, target: "header", label: " "},
                {tag: "center-body", center: true, target: "notificationBody", label: " "},
                {tag: "center-enter", center: true, target: "enter", label: " "},
                {tag: "named-default", center: false, target: "notificationSummary", label: "Otwórz"}
            ];
        }
        function test_kitty_default_has_no_button(data) {
            const id = send({appName: "kitty", body: "Zakończono zadanie", actions: [["default", data.label]]});
            waitCard();
            const item = data.center ? openCenter().page.cardAt(0) : card();
            compare(item.actionItems.count, 0);
            verify(waitForPolish(scene));
            const defaultHeight = item.height;
            backend.send({replacesId: id, actions: []});
            verify(waitForPolish(scene));
            compare(item.height, defaultHeight, "Default action must not reserve a button row");
            backend.send({replacesId: id, actions: [["default", data.label]]});
            if (data.target === "enter") {
                item.selectionControl.forceActiveFocus(Qt.TabFocusReason);
                keyClick(Qt.Key_Return);
            } else if (data.target === "header") mouseClick(item, 70, 30);
            else mouseClick(findChild(item, data.target), 15, 8);
            compare(backend.actionEvents, [{id: id, action: "default"}]);
            verify(closed(id, 2));
            if (!data.center) verify(desktop.activeFocus);
        }
        function test_card_without_action_does_not_dismiss_and_single_action_works() {
            send();
            const surface = openCenter();
            keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            compare(backend.actionEvents.length, 0); compare(notifications.history.length, 1);
            compare(preview.coordinator.activeId, "notifications");
            const id = send({actions: [["open", "Otwórz"]]});
            tryVerify(() => surface.page.cardAt(0).entry.notificationId === id);
            surface.page.cardAt(0).selectionControl.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            compare(backend.actionEvents.length, 1); compare(backend.actionEvents[0].action, "open");
            verify(closed(id, 2));
        }
        function test_center_expand_navigation_and_escape_data() {
            return [{tag: "desktop-escape", width: 1366, height: 768, key: Qt.Key_Escape},
                {tag: "small-escape", width: 320, height: 220, key: Qt.Key_Escape},
                {tag: "desktop-q", width: 1366, height: 768, key: Qt.Key_Q},
                {tag: "small-q", width: 320, height: 220, key: Qt.Key_Q}];
        }
        function test_center_expand_navigation_and_escape(data) {
            scene.width = data.width; scene.height = data.height;
            notifications.dnd = true;
            send({summary: "Następne"});
            send({summary: "Długi tytuł ".repeat(35), body: "Pełny tekst powiadomienia. ".repeat(120)});
            const surface = openCenter();
            const first = surface.page.cardAt(0), second = surface.page.cardAt(1);
            const summary = findChild(first, "notificationSummary"), body = findChild(first, "notificationBody");
            verify(summary.truncated); verify(body.truncated); verify(first.expandControl.visible);
            keyClick(Qt.Key_J); verify(first.selectionControl.activeFocus);
            const collapsedHeight = first.height;
            keyClick(Qt.Key_I); tryCompare(first, "expanded", true);
            verify(waitForPolish(scene));
            tryCompare(summary, "truncated", false); tryCompare(body, "truncated", false);
            tryVerify(() => first.height > collapsedHeight);
            verify(first.selectionControl.activeFocus);
            keyClick(Qt.Key_I); verify(first.expanded);
            keyClick(Qt.Key_J); verify(second.selectionControl.activeFocus);
            verify(surface.viewport.contentY > 0);
            keyClick(Qt.Key_K); verify(first.selectionControl.activeFocus); verify(first.expanded);
            const point = first.mapToItem(surface.viewport, 0, 0);
            verify(point.y >= 0 && point.y < 20, "Return reveals the top of the expanded card");
            first.closeControl.forceActiveFocus(Qt.TabFocusReason);
            keyClick(data.key); tryCompare(first, "expanded", false);
            compare(preview.coordinator.activeId, "notifications"); verify(first.selectionControl.activeFocus);
            tryCompare(first, "height", collapsedHeight);
            keyClick(data.key); tryCompare(preview.panelHost, "loaded", false);
        }
        function test_expand_pointer_and_no_keyboard_ring() {
            send({body: "Długi tekst ".repeat(200), resident: true, actions: [["default", "Otwórz"]]});
            const surface = openCenter(), item = surface.page.cardAt(0);
            keyClick(Qt.Key_J); verify(item.selectionControl.activeFocus);
            mouseClick(item.expandControl);
            tryCompare(item, "expanded", true);
            compare(backend.actionEvents.length, 0);
            verify(!findChild(item.selectionControl, "focusIndicator").visible);
            mouseClick(item.expandControl);
            tryCompare(item, "expanded", false);
            compare(backend.actionEvents.length, 0);
            mouseMove(scene, 40, 400);
            compare(item.closeControl.background.color, Qt.rgba(0, 0, 0, 0));
            compare(item.closeControl.background.border.width, 0);
        }
        function test_center_wheel_over_cards_and_reveal_last_data() {
            return [{tag: "short", body: "Krótki tekst"}, {tag: "long", body: "Długi tekst ".repeat(200)}];
        }
        function test_center_wheel_over_cards_and_reveal_last(data) {
            scene.width = 320; scene.height = 400;
            notifications.dnd = true;
            for (let i = 0; i < 20; ++i) send({summary: "Pozycja " + i, body: data.body});
            const surface = openCenter(), viewport = surface.viewport;
            const first = surface.page.cardAt(0), last = surface.page.cardAt(19);
            verify(viewport.contentHeight > viewport.height);
            compare(viewport.contentY, 0);
            mouseWheel(findChild(first, "notificationBody"), 20, 8, 0, -120);
            tryVerify(() => viewport.contentY > 0);
            compare(first.viewport.contentY, 0);
            last.selectionControl.forceActiveFocus(Qt.TabFocusReason);
            verify(waitForPolish(scene));
            const point = last.mapToItem(viewport, 0, 0);
            verify(point.y >= 0 && point.y < viewport.height);
            keyClick(Qt.Key_K); verify(surface.page.cardAt(18).selectionControl.activeFocus);
            keyClick(Qt.Key_J); verify(last.selectionControl.activeFocus);
            first.selectionControl.forceActiveFocus(Qt.TabFocusReason);
            if (first.expandable) {
                keyClick(Qt.Key_I); verify(first.expanded);
                verify(waitForPolish(scene));
                const before = viewport.contentY;
                mouseWheel(findChild(first, "notificationBody"), 20, 8, 0, -120);
                tryVerify(() => viewport.contentY > before);
                compare(first.viewport.contentY, 0);
            }
            compare(backend.actionEvents.length, 0);
        }
        function test_toast_expand_navigation_and_body_click_data() {
            return [{tag: "escape", key: Qt.Key_Escape}, {tag: "q", key: Qt.Key_Q}];
        }
        function test_toast_expand_navigation_and_body_click(data) {
            send({body: "Długi tekst ".repeat(200), resident: true, actions: [["default", "Otwórz"]]});
            send({summary: "Drugie"}); waitCard();
            const first = card(), second = card(1);
            preview.notificationController.enter(); tryVerify(() => first.selectionControl.activeFocus);
            keyClick(Qt.Key_I); verify(first.expanded);
            tryCompare(findChild(first, "notificationBody"), "truncated", false);
            tryVerify(() => first.viewport.contentHeight > first.viewport.height);
            keyClick(Qt.Key_J); verify(second.selectionControl.activeFocus);
            keyClick(Qt.Key_K); verify(first.selectionControl.activeFocus); verify(first.expanded);
            keyClick(data.key); verify(!first.expanded); compare(preview.notificationController.screenName, "TEST-1");
            keyClick(data.key); compare(preview.notificationController.screenName, "");
            desktop.forceActiveFocus();
            mouseClick(findChild(first, "notificationBody"), 15, 8);
            compare(backend.actionEvents.length, 0); verify(first.expanded);
            mouseClick(findChild(first, "notificationBody"), 15, 8);
            compare(backend.actionEvents.length, 1); verify(desktop.activeFocus);
        }
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
            backend.send({replacesId: id, summary: "<b>hjkl & tytuł</b>", body: "<img src='https://example.invalid/x'>" + "długi ".repeat(2000), actions: [["default", " "], ["open", "<b>Otwórz</b>"]]});
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
            send({actions: [["default", " "], ["open", "Otwórz"]]}); waitCard();
            mouseClick(card().actionAt(0)); verify(desktop.activeFocus); compare(backend.actionEvents.length, 1);
            compare(backend.actionEvents[0].action, "open");
        }
        function test_keyboard_hjkl_enter_escape_and_tooltip() {
            const id = send({resident: true, actions: [["a", "Akcja A"], ["default", " "], ["b", "Akcja B"], ["c", "Akcja C"], ["d", "Akcja D"]]});
            waitCard(); preview.notificationController.enter();
            tryVerify(() => card().selectionControl.activeFocus);
            verify(findChild(card().selectionControl, "focusIndicator").visible);
            keyClick(Qt.Key_L); keyClick(Qt.Key_J); verify(card().actionAt(0).activeFocus);
            keyClick(Qt.Key_L); verify(card().actionAt(1).activeFocus);
            keyClick(Qt.Key_J); verify(card().actionAt(3).activeFocus);
            keyClick(Qt.Key_H); verify(card().actionAt(2).activeFocus);
            keyClick(Qt.Key_K); verify(card().actionAt(0).activeFocus);
            keyClick(Qt.Key_Enter); compare(backend.actionEvents.length, 1); compare(backend.actionEvents[0].action, "a");
            verify(notifications.find(id) !== null); compare(preview.notificationController.screenName, "");
            preview.notificationController.enter(); tryVerify(() => card().selectionControl.activeFocus);
            keyClick(Qt.Key_Tab); verify(card().closeControl.activeFocus);
            keyClick(Qt.Key_Tab); verify(card().actionAt(0).activeFocus);
            keyClick(Qt.Key_Backtab); verify(card().closeControl.activeFocus);
            keyClick(Qt.Key_Backtab); verify(card().selectionControl.activeFocus);
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
            preview.notificationController.enter(); tryVerify(() => card().selectionControl.activeFocus);
            card().closeControl.forceActiveFocus(Qt.TabFocusReason);
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
            tryVerify(() => card().selectionControl.activeFocus); wait(150); verify(notifications.find(id) !== null);
            const original = card(); send(); compare(card(), original); verify(card().selectionControl.activeFocus);
            keyClick(Qt.Key_L); keyClick(Qt.Key_Return); verify(closed(id, 2));
            tryVerify(() => card().selectionControl.activeFocus);
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
            send(); keyClick(Qt.Key_J); verify(preview.panelHost.window.page.cardAt(0).selectionControl.activeFocus);
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
