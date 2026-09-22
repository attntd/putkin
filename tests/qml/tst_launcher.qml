import QtQuick
import QtTest
import "../../core"
import "../../preview"
import "../../services"
import "../../services/LauncherQuery.js" as Query
import "IconPixels.js" as Pixels

Item {
    id: scene
    width: 1000
    height: 700
    MockLauncherBackend { id: backend }
    LauncherService { id: launcher; backend: backend; workspaceService: preview.workspaceService }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notices; backend: notificationBackend; screens: preview.coordinator.screens; monitorService: preview.backend }
    QtObject {
        id: loader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader {
            active: loader.activeAsync
            asynchronous: true
            sourceComponent: preview.panelComponent
        }
    }
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: loader; launcher: launcher }
    SignalSpy { id: activated; target: launcher; signalName: "activated" }
    TestCase {
        name: "Launcher"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false);
            tryCompare(loader, "active", false);
            preview.workspaceService.cancelAction("");
            preview.workspaceService.actionTimeout = 2000;
            preview.backend.reset();
            backend.reset();
            preview.notifications = null;
            preview.errorNotificationsEnabled = false;
            preview.coordinator.screens = [preview.firstScreen, preview.secondScreen];
            scene.width = 1000; scene.height = 700;
            mouseMove(scene, 0, 0);
            activated.clear();
        }
        function cleanup() { preview.coordinator.close(false); tryCompare(loader, "active", false); }
        function open() {
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => loader.item.page !== null);
            tryVerify(() => search().activeFocus);
            tryCompare(loader.item, "opacity", 1);
        }
        function search() { return findChild(loader.item, "launcherSearch"); }
        function chip() { return findChild(loader.item, "launcherChip"); }
        function list() { return findChild(loader.item, "launcherResults"); }
        function settleResults() {
            const fade = findChild(loader.item, "launcherResultsFade");
            tryVerify(() => fade.requested ? fade.current && fade.opacity === 1 : fade.opacity === 0);
        }
        function settlePreview() {
            const fade = findChild(loader.item, "launcherPreviewFade");
            if (preview.panelHost.launcherPreviewSize > 0 && (backend.automatic || launcher.previewText.length || launcher.previewImage.length))
                tryVerify(() => fade.current && fade.contentReady && fade.opacity === 1
                    && fade.displayedValue.id === launcher.previewId);
        }
        function type(value) {
            for (let index = 0; index < value.length; index++) keyClick(value[index]);
            settleResults();
            settlePreview();
        }
        function clipboardFixture() {
            backend.clipboard = [
                {id: "12", preview: "Pierwsza linia", binary: false, fullText: "  <b>Tekst dosłowny</b>\n" + "Zażółć gęślą jaźń.\n".repeat(80)},
                {id: "11", preview: "[[ binary data png 640x360 ]]", binary: true, image: Qt.resolvedUrl("../fixtures/launcher-preview.png").toString()}
            ];
        }
        function test_search_center_is_fixed_data() {
            return [{tag: "wide", width: 1920, height: 1080}, {tag: "laptop", width: 1366, height: 768},
                {tag: "compact", width: 1000, height: 700}, {tag: "narrow", width: 800, height: 600},
                {tag: "tiny", width: 320, height: 220}];
        }
        function test_search_center_is_fixed(data) {
            scene.width = data.width; scene.height = data.height;
            open(); settleResults();
            const field = search(), origin = field.mapToItem(scene, 0, 0), panelX = loader.item.x;
            fuzzyCompare(origin.y + field.height / 2, data.height / 2, 0.5);
            type(":c ");
            compare(field.mapToItem(scene, 0, 0).y, origin.y);
            compare(loader.item.x, panelX);
            search().selectAll(); keyClick(Qt.Key_Backspace); type("no matching clipboard item");
            compare(field.mapToItem(scene, 0, 0).y, origin.y);
            compare(loader.item.x, panelX);
            verify(loader.item.y + loader.item.primaryHeight <= data.height - Metrics.panelGap);
        }
        function test_five_visible_results_with_keyboard_wheel_and_scrollbar_data() {
            return [{tag: "apps", clipboard: false, rowHeight: 52}, {tag: "clipboard", clipboard: true, rowHeight: 36}];
        }
        function test_five_visible_results_with_keyboard_wheel_and_scrollbar(data) {
            const oldApps = backend.applications, oldClipboard = backend.clipboard;
            try {
                if (data.clipboard) backend.clipboard = Array.from({length: 20}, (_, i) => ({id: String(i), preview: "Entry " + i, binary: false}));
                else backend.applications = Array.from({length: 20}, (_, i) => ({id: "app-" + i, name: "App " + i}));
                open(); type(data.clipboard ? ":c " : ":a ");
                compare(list().count, 20);
                compare(list().currentIndex, -1);
                compare(list().height, data.rowHeight * 5);
                const bar = findChild(loader.item, "launcherResultsScrollbar");
                verify(bar.visible && bar.size < 1);
                compare(bar.contentItem.radius, 0);
                keyClick(Qt.Key_Escape); keyClick(Qt.Key_End);
                compare(loader.item.page.selectedIndex, 19);
                tryVerify(() => list().contentY > 0);
                list().forceLayout();
                const last = list().itemAtIndex(19);
                verify(last !== null && last.y + last.height <= list().contentY + list().height + 1);
                keyClick(Qt.Key_Home);
                tryCompare(list(), "contentY", 0);
                mouseWheel(list(), 30, 30, 0, -120);
                tryVerify(() => list().contentY > 0);
                list().cancelFlick();
                list().contentY = 0;
                const knob = bar.contentItem;
                mouseDrag(bar, bar.width / 2, knob.y + knob.height / 2, 0, bar.height / 2);
                verify(list().contentY > 0);
                compare(list().focusReason, Qt.MouseFocusReason);
                compare(backend.activations.length, 0);
            } finally { backend.applications = oldApps; backend.clipboard = oldClipboard; }
        }
        function test_results_resize_only_while_transparent_and_keep_latest_query() {
            const original = backend.applications;
            try {
                backend.applications = Array.from({length: 12}, (_, i) => ({id: "fixture-" + i, name: "Fixture " + i}));
                open(); type(":a ");
                const fade = findChild(loader.item, "launcherResultsFade");
                const origin = search().mapToItem(scene, 0, 0), oldHeight = fade.height;
                launcher.edit("Fixture 1");
                compare(fade.displayedValue.entries.length, 12);
                tryVerify(() => fade.opacity > 0 && fade.opacity < 1);
                compare(fade.height, oldHeight);
                launcher.edit("Fixture 11");
                settleResults();
                compare(fade.displayedValue.entries.length, 1);
                compare(list().itemAtIndex(0).modelData.id, "fixture-11");
                verify(fade.height < oldHeight);
                compare(search().mapToItem(scene, 0, 0), origin);
                verify(!fade.fadePresentation.preparation.running);
            } finally { backend.applications = original; }
        }
        function test_preview_holds_old_text_during_fade_then_reveals_image() {
            const original = backend.clipboard;
            try {
                clipboardFixture(); open(); type(":c ");
                const fade = findChild(loader.item, "launcherPreviewFade");
                const previous = fade.displayedValue.text;
                keyClick(Qt.Key_Down);
                tryVerify(() => fade.opacity > 0 && fade.opacity < 1);
                compare(fade.displayedValue.text, previous);
                tryCompare(launcher, "previewImage", backend.clipboard[1].image);
                settlePreview();
                compare(fade.displayedValue.id, "11");
                const frame = findChild(loader.item, "launcherPreview");
                compare(findChild(frame, "launcherPreviewImage").status, Image.Ready);
                launcher.edit("missing clipboard item");
                tryVerify(() => fade.opacity > 0 && fade.opacity < 1);
                compare(findChild(loader.item, "launcherPreview"), frame);
                tryVerify(() => findChild(loader.item, "launcherPreview") === null);
                compare(fade.displayedValue, null);
            } finally { backend.clipboard = original; }
        }
        function test_filtered_lists_and_compact_clipboard() {
            open();
            for (const mode of ["application", "file", "clipboard", "recent"]) {
                launcher.chipMode = mode;
                launcher.edit("");
                settleResults();
                tryCompare(findChild(loader.item, "launcherHeading"), "visible", false);
                verify(chip().visible);
                if (mode === "clipboard" || mode === "application") {
                    tryVerify(() => list().itemAtIndex(0) !== null);
                    const row = list().itemAtIndex(0), compact = mode === "clipboard";
                    compare(row.height, compact ? 36 : 52);
                    compare(findChild(row, "launcherApplicationIcon").visible, !compact);
                    compare(findChild(row, "launcherRowSubtitle").visible, !compact);
                    compare(findChild(row, "launcherRowTitle").maximumLineCount, 1);
                }
            }
        }
        function test_clipboard_preview_text_image_and_vim_scroll_data() {
            return [{tag: "h", key: Qt.Key_H}, {tag: "escape", key: Qt.Key_Escape}, {tag: "q", key: Qt.Key_Q}];
        }
        function test_clipboard_preview_text_image_and_vim_scroll(data) {
            const original = backend.clipboard;
            try {
                clipboardFixture(); open(); type(":c ");
                tryCompare(launcher, "previewText", backend.clipboard[0].fullText);
                const frame = findChild(loader.item, "launcherPreview");
                verify(frame !== null);
                compare(frame.width, frame.height);
                compare(frame.mapToItem(loader.item, 0, 0).y, 0);
                compare(frame.mapToItem(loader.item, 0, 0).x, Metrics.launcherWidth + Metrics.panelGap);
                compare(findChild(frame, "launcherPreviewText").textFormat, Text.PlainText);
                keyClick(Qt.Key_Escape); keyClick(Qt.Key_L);
                verify(frame.activeFocus);
                const scroll = findChild(frame, "launcherPreviewScroll");
                keyClick(Qt.Key_J); verify(scroll.contentY > 0);
                keyClick(Qt.Key_K); compare(scroll.contentY, 0);
                keyClick(data.key); verify(list().activeFocus);
                keyClick(Qt.Key_J);
                tryCompare(launcher, "previewImage", backend.clipboard[1].image);
                compare(launcher.previewText, "");
                const image = findChild(frame, "launcherPreviewImage");
                tryCompare(image, "status", Image.Ready);
                verify(waitForPolish(scene));
                compare(image.fillMode, Image.PreserveAspectFit);
                verify(Math.abs(image.paintedWidth / image.paintedHeight - 640 / 360) < 0.01);
                verify(image.paintedWidth <= image.width && image.paintedHeight <= image.height);
                compare(backend.activations.length, 0);
                keyClick(Qt.Key_L); keyClick(Qt.Key_Return);
                tryCompare(preview.coordinator, "activeId", "");
                compare(backend.activations[0].entry.id, "11");
                compare(launcher.previewText, ""); compare(launcher.previewImage, ""); compare(launcher.previewId, "");
            } finally { backend.clipboard = original; }
        }
        function test_preview_pointer_selection_and_focus() {
            const original = backend.clipboard;
            try {
                clipboardFixture(); open(); type(":c ");
                tryCompare(launcher, "previewId", "12");
                keyClick(Qt.Key_Escape);
                list().forceLayout();
                const second = list().itemAtIndex(1);
                verify(waitForPolish(scene));
                mouseMove(second, second.width / 2, second.height / 2);
                tryCompare(launcher, "previewId", "11");
                compare(backend.activations.length, 0);
                verify(!findChild(second, "focusIndicator").visible);
                settlePreview();
                keyClick(Qt.Key_L);
                const frame = findChild(loader.item, "launcherPreview");
                const ring = findChild(frame, "focusIndicator");
                verify(frame.activeFocus); verify(ring.visible);
                mouseClick(frame, frame.width / 2, frame.height / 2);
                compare(preview.coordinator.activeId, "launcher");
                verify(!ring.visible);
                keyClick(Qt.Key_H); verify(list().activeFocus);
                backend.automatic = false;
                mouseClick(second, second.width / 2, second.height / 2);
                verify(!findChild(second, "focusIndicator").visible);
                compare(backend.activations.length, 1);
                backend.activated(launcher.request, "Odmowa");
            } finally { backend.clipboard = original; }
        }
        function test_text_preview_click_keeps_navigation() {
            const original = backend.clipboard;
            try {
                clipboardFixture(); open(); type(":c ");
                const frame = findChild(loader.item, "launcherPreview");
                keyClick(Qt.Key_Escape); keyClick(Qt.Key_L);
                verify(frame.activeFocus);
                mouseClick(frame, frame.width / 2, frame.height / 2);
                verify(!findChild(frame, "focusIndicator").visible);
                const bar = findChild(frame, "launcherPreviewScrollbar");
                compare(bar.height, frame.availableHeight);
                verify(bar.visible && bar.size < 1);
                const knob = bar.contentItem;
                mouseDrag(bar, bar.width / 2, knob.y + knob.height / 2, 0, bar.height / 2);
                verify(findChild(frame, "launcherPreviewScroll").contentY > 0);
                verify(!findChild(frame, "focusIndicator").visible);
                keyClick(Qt.Key_H); verify(list().activeFocus);
            } finally { backend.clipboard = original; }
        }
        function test_preview_ignores_stale_replies_filter_and_close() {
            const original = backend.clipboard;
            try {
                clipboardFixture(); open(); backend.automatic = false; type(":c ");
                tryCompare(launcher, "previewId", "12");
                const old = launcher.previewRevision;
                keyClick(Qt.Key_Down);
                compare(launcher.previewId, "11");
                backend.previewed(old, "12", "stary tekst", "", "");
                compare(launcher.previewText, "");
                backend.previewed(launcher.previewRevision, "11", "", backend.clipboard[1].image, "");
                compare(launcher.previewImage, backend.clipboard[1].image);
                launcher.edit("brak dopasowania");
                tryCompare(launcher, "previewId", "");
                compare(launcher.previewImage, "");
                tryVerify(() => findChild(loader.item, "launcherPreview") === null);
                const closed = launcher.previewRevision;
                preview.coordinator.close(false);
                backend.previewed(closed, "", "spóźniony tekst", "", "");
                compare(launcher.previewText, "");
            } finally { backend.clipboard = original; }
        }
        function test_preview_geometry_data() {
            return [{tag: "wide", width: 1920, height: 1080, size: 320},
                {tag: "laptop", width: 1366, height: 768, size: 320},
                {tag: "shifted", width: 1024, height: 700, size: 320},
                {tag: "smaller", width: 900, height: 700, size: 236},
                {tag: "narrow", width: 800, height: 600, size: 0},
                {tag: "tiny", width: 320, height: 220, size: 0}];
        }
        function test_preview_geometry(data) {
            scene.width = data.width; scene.height = data.height;
            open(); type(":c ");
            tryCompare(launcher, "previewId", backend.clipboard[0].id);
            tryCompare(preview.panelHost, "launcherPreviewSize", data.size);
            verify(waitForPolish(scene));
            const panel = loader.item;
            compare(preview.panelHost.surfaceWidth, Math.min(640, data.width - Metrics.panelGap * 2));
            verify(panel.x >= Metrics.panelGap);
            verify(panel.x + panel.width <= data.width - Metrics.panelGap);
            verify(panel.y >= Metrics.barHeight + Metrics.panelGap);
            verify(panel.y + panel.height <= data.height - Metrics.panelGap);
            compare(findChild(panel, "launcherPreview") !== null, data.size > 0);
        }
        function test_preview_disappears_while_focused() {
            open(); type(":c ");
            tryVerify(() => findChild(loader.item, "launcherPreview") !== null);
            keyClick(Qt.Key_Escape); keyClick(Qt.Key_L);
            verify(findChild(loader.item, "launcherPreview").activeFocus);
            scene.width = 800;
            tryVerify(() => findChild(loader.item, "launcherPreview") === null);
            tryVerify(() => list().activeFocus);
            keyClick(Qt.Key_J);
            compare(loader.item.page.selectedIndex, 1);
        }
        function test_application_icons_data() {
            return [{tag: "known", id: "kitty", icon: "", symbol: "terminal"},
                {tag: "tether", id: "tether-gtk", icon: "tether", symbol: "putkin_tether"},
                {tag: "signal", id: "signal", icon: "signal-desktop", symbol: "chat_bubble"},
                {tag: "otherMessenger", id: "fixture", icon: "", categories: ["InstantMessaging"], symbol: "chat"},
                {tag: "missing", id: "fixture", icon: "missing", symbol: "apps"},
                {tag: "empty", id: "fixture", icon: "", symbol: "apps"},
                {tag: "bitmap", id: "fixture", icon: "/no/colored.png", symbol: "apps"}];
        }
        function test_application_icons(data) {
            const original = backend.applications;
            try {
                backend.applications = [{id: data.id, name: "Fixture", icon: data.icon, categories: data.categories || []}];
                open(); type(":a fixture");
                tryCompare(list(), "count", 1);
                tryVerify(() => list().itemAtIndex(0) !== null);
                const row = list().itemAtIndex(0);
                const icon = findChild(row, "launcherApplicationIcon");
                compare(icon.width, 32); compare(icon.height, 32);
                compare(icon.iconSize, 24); compare(icon.iconPadding, 4);
                compare(icon.symbol, data.symbol);
                compare(icon.mapToItem(row, 0, icon.height / 2).y, row.height / 2);
                Pixels.verifyIcon(this, scene, icon, row.background.color);
                keyClick(Qt.Key_Escape); keyClick(Qt.Key_Return);
                tryCompare(preview.coordinator, "activeId", "");
                compare(backend.activations.length, 1);
                compare(backend.activations[0].entry.id, data.id);
            } finally { backend.applications = original; }
        }
        function test_search_focus_colors_its_own_border() {
            open();
            tryCompare(loader.item, "opacity", 1);
            const field = search(), ring = findChild(field, "focusIndicator");
            verify(ring.visible);
            compare(ring.width, field.width); compare(ring.height, field.height);
            compare(ring.mapToItem(field, 0, 0), Qt.point(0, 0));
            verify(waitForPolish(scene));
            verify(waitForRendering(scene));
            const image = grabImage(scene), origin = field.mapToItem(scene, 0, 0);
            const x = Math.round(origin.x), y = Math.round(origin.y);
            verify(image.pixel(x + 1, y + 1) !== Theme.border);
            compare(image.pixel(x + 3, y + 3), Theme.background);
            mouseClick(field); verify(!ring.visible);
            type("hjkl"); compare(launcher.text, "hjkl"); verify(ring.visible);
            compare(ring.width, field.width);
        }
        function test_workspace_commands_data() {
            const cases = [];
            for (const action of ["switch", "move"])
                for (let digit = 0; digit <= 9; digit++)
                    cases.push({ tag: action + digit, action: action, digit: digit });
            return cases;
        }
        function test_workspace_commands(data) {
            open();
            // Keyboard focus can change after opening; the captured window must not.
            preview.backend.activeWindow = preview.backend.secondWindow;
            const destination = data.digit === 0 ? 10 : data.digit;
            type((data.action === "move" ? ":mw" : ":w") + data.digit);
            compare(launcher.results.length, 1);
            compare(launcher.results[0].workspaceId, destination);
            verify(launcher.results[0].title.endsWith(" " + destination));
            tryVerify(() => list().itemAtIndex(0) !== null);
            verify(findChild(list().itemAtIndex(0), "launcherRowSubtitle").visible);
            compare(findChild(list().itemAtIndex(0), "launcherRowSubtitle").text, "Workspace");
            compare(findChild(list().itemAtIndex(0), "launcherApplicationIcon").symbol, "desktop_windows");
            compare(launcher.chipMode, "");
            compare(preview.backend.requests.length, 0);
            verify(!launcher.searching);
            keyClick(Qt.Key_Return);
            tryCompare(preview.coordinator, "activeId", "");
            compare(activated.count, 1);
            verify(!launcher.busy);
            compare(backend.activations.length, 0);
            compare(backend.searches.filter(item => item.query.length > 0).length, 0);
            if (data.action === "move") {
                compare(preview.backend.requests, [{kind: "move", workspaceId: destination, address: "0x123"}]);
                compare(preview.backend.firstWindow.workspace.id, destination);
                compare(preview.backend.secondWindow.workspace.id, 2);
                compare(preview.workspaceService.activeId("TEST-1"), 9);
            } else compare(preview.workspaceService.activeId("TEST-1"), destination);
        }
        function test_workspace_incomplete_and_invalid_commands() {
            open();
            for (const value of [":", ":w", ":mw", ":w10", ":mw10", ":w-1", ":mw1foo", ":w1;foo", ":mw 2"]) {
                search().selectAll(); keyClick(Qt.Key_Backspace); type(value);
                verify(launcher.commandInput);
                compare(launcher.results.length, 0);
                verify(!findChild(loader.item, "launcherEmptyState").visible);
                keyClick(Qt.Key_Return);
                compare(preview.coordinator.activeId, "launcher");
                compare(preview.backend.requests.length, 0);
            }
            wait(180);
            compare(backend.activations.length, 0);
            compare(backend.searches.filter(item => item.query.length > 0).length, 0);
        }
        function test_direct_modes_reset_query_and_focus() {
            open();
            compare(findChild(loader.item, "launcherHeading").text, "Ostatnie");
            type(":a terminal");
            keyClick(Qt.Key_Escape);
            launcher.startMode("clipboard");
            verify(search().activeFocus);
            compare(launcher.mode, "clipboard");
            compare(search().text, "");
            verify(chip().visible);
            verify(launcher.results.every(entry => entry.kind === "clipboard"));
            launcher.startMode("commands");
            settleResults();
            verify(search().activeFocus);
            verify(chip().visible);
            compare(chip().text, "Komenda");
            compare(chip().trailingIcon, "close");
            verify(!findChild(loader.item, "launcherHeading").visible);
            compare(search().text, "");
            compare(search().cursorPosition, 0);
            verify(launcher.commandInput);
            compare(launcher.results.length, 0);
            type("w3");
            keyClick(Qt.Key_Return);
            tryCompare(preview.coordinator, "activeId", "");
            compare(preview.workspaceService.activeId("TEST-1"), 3);
            open();
            compare(search().text, "");
            verify(!launcher.commandInput);
        }
        function test_workspace_text_in_filter_is_literal() {
            const original = backend.clipboard;
            backend.clipboard = [{id: "commandText", preview: ":w3", binary: false}];
            open(); type(":c :w3");
            verify(!launcher.commandInput);
            compare(launcher.results[0].kind, "clipboard");
            keyClick(Qt.Key_Return);
            tryCompare(preview.coordinator, "activeId", "");
            compare(backend.activations[0].entry.id, "commandText");
            compare(preview.backend.requests.length, 0);
            backend.clipboard = original;
        }
        function test_workspace_monitor_and_helper_unavailable() {
            verify(preview.coordinator.open("launcher", preview.secondScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => search().activeFocus);
            backend.ready = false;
            backend.lastError = "Pomocnik niedostępny";
            type(":W0");
            keyClick(Qt.Key_Return);
            tryCompare(preview.coordinator, "activeId", "");
            compare(preview.backend.requests, [{kind: "focus", monitorName: "TEST-2"},
                {kind: "activate", workspaceId: 10, monitorName: "TEST-2"}]);
            compare(launcher.lastError, "");
        }
        function test_workspace_move_missing_and_closed_window() {
            preview.backend.activeWindow = null;
            open(); type(":mw4"); keyClick(Qt.Key_Return);
            compare(preview.coordinator.activeId, "launcher");
            verify(launcher.lastError.length > 0);
            compare(preview.backend.requests.length, 0);
            preview.coordinator.close(false); tryCompare(loader, "active", false);
            preview.backend.activeWindow = preview.backend.firstWindow;
            open(); type(":mw4");
            preview.backend.windows = [preview.backend.secondWindow];
            preview.backend.activeWindow = preview.backend.secondWindow;
            keyClick(Qt.Key_Return);
            verify(launcher.lastError.length > 0);
            compare(preview.backend.requests.length, 0);
            verify(!launcher.busy);
        }
        function test_workspace_move_acknowledgement_and_duplicate_enter() {
            open(); type(":mw6");
            preview.backend.autoAcknowledge = false;
            keyClick(Qt.Key_Return); keyClick(Qt.Key_Return);
            compare(preview.backend.requests.length, 1);
            verify(launcher.busy);
            backend.activated(launcher.request, ""); // Different backend cannot acknowledge this command.
            verify(launcher.busy);
            compare(preview.coordinator.activeId, "launcher");
            preview.backend.firstWindow.workspace = {id: 6};
            tryCompare(preview.coordinator, "activeId", "");
            verify(!launcher.busy);
            compare(activated.count, 1);
        }
        function test_workspace_move_closes_while_pending() {
            open(); type(":mw6");
            preview.backend.autoAcknowledge = false;
            keyClick(Qt.Key_Return);
            preview.backend.windows = [preview.backend.secondWindow];
            preview.backend.activeWindow = preview.backend.secondWindow;
            verify(!launcher.busy);
            verify(launcher.lastError.length > 0);
            compare(preview.backend.requests, [{kind: "move", workspaceId: 6, address: "0x123"}]);
            compare(preview.coordinator.activeId, "launcher");
        }
        function test_workspace_timeout_disconnect_and_late_session() {
            open(); type(":w6");
            preview.backend.autoAcknowledge = false;
            preview.workspaceService.actionTimeout = 60;
            keyClick(Qt.Key_Return);
            tryCompare(launcher, "busy", false);
            verify(launcher.lastError.length > 0);
            compare(preview.coordinator.activeId, "launcher");
            preview.workspaceService.actionTimeout = 2000;
            keyClick(Qt.Key_Return);
            verify(launcher.busy);
            preview.backend.connected = false;
            tryCompare(launcher, "busy", false);
            verify(launcher.lastError.length > 0);
            preview.backend.connected = true;
            keyClick(Qt.Key_Return);
            verify(launcher.busy);
            preview.coordinator.close(false); tryCompare(loader, "active", false);
            open();
            preview.backend.monitors = [{name: "TEST-1", activeId: 6}, {name: "TEST-2", activeId: 2}];
            verify(!launcher.busy);
            compare(preview.coordinator.activeId, "launcher");
            compare(activated.count, 0);
        }
        function test_chips_and_backspace_with_real_text_input() {
            open();
            type(":a ");
            compare(launcher.chipMode, "application");
            compare(search().text, "");
            verify(chip().visible);
            compare(chip().text, "Aplikacje");
            type("hjkl");
            compare(search().text, "hjkl");
            compare(launcher.query, "hjkl");
            search().selectAll(); keyClick(Qt.Key_Backspace);
            keyClick(Qt.Key_Backspace);
            compare(launcher.chipMode, "");
            compare(search().text, ":a");
            keyClick(Qt.Key_Space);
            compare(launcher.chipMode, "application");
            verify(waitForPolish(scene));
            verify(waitForRendering(scene));
            mousePress(chip(), chip().width / 2, chip().height / 2);
            verify(chip().pressed);
            mouseRelease(chip(), chip().width / 2, chip().height / 2);
            compare(launcher.chipMode, "");
            verify(search().activeFocus);
        }
        function test_all_prefixes_paste_and_literal_colon() {
            open();
            for (const mode of [{text: ":C zawartość", kind: "clipboard"}, {text: ":f Plan", kind: "file"}, {text: ": balanced", kind: "command"}]) {
                launcher.removeFilter(false);
                launcher.edit(mode.text);
                compare(launcher.chipMode, mode.kind);
                compare(search().text, mode.text.split(" ")[1]);
            }
            launcher.removeFilter(false);
            launcher.edit(":xyz");
            compare(launcher.chipMode, "");
            compare(launcher.query, ":xyz");
        }
        function test_colon_space_commits_command_chip_and_backspace_restores_prefix() {
            open(); type(":");
            compare(launcher.chipMode, "");
            keyClick(Qt.Key_Space);
            compare(launcher.chipMode, "command");
            verify(chip().visible); compare(chip().text, "Komenda");
            compare(search().text, ""); compare(search().cursorPosition, 0);
            verify(search().activeFocus); verify(launcher.commandInput); verify(!launcher.historyView);
            keyClick(Qt.Key_Backspace);
            compare(launcher.chipMode, ""); compare(search().text, ":");
            compare(search().cursorPosition, 1); verify(search().activeFocus);
            keyClick(Qt.Key_Space); type("w3");
            compare(launcher.command.workspaceId, 3); compare(search().text, "w3");
            compare(preview.backend.requests.length, 0); compare(backend.activations.length, 0);
            search().selectAll(); keyClick(Qt.Key_Backspace);
            mouseClick(chip());
            compare(launcher.chipMode, ""); verify(search().activeFocus);
            compare(search().text, ""); verify(launcher.historyView);
            compare(launcher.results[0].title, "Kitty");
        }
        function test_pasted_command_prefix_and_literal_filtered_colon() {
            open(); launcher.edit(":   balanced");
            compare(launcher.chipMode, "command"); compare(search().text, "balanced");
            compare(launcher.commandText, ":balanced");
            launcher.edit(": w3");
            compare(search().text, "w3"); compare(launcher.command.workspaceId, 3);
            for (const prefix of [":a ", ":f ", ":c "]) {
                launcher.startMode("commands"); launcher.edit(prefix);
                verify(!launcher.commandInput);
                launcher.edit(": balanced");
                verify(!launcher.commandInput); compare(launcher.query, ": balanced");
            }
            compare(preview.backend.requests.length, 0); compare(backend.activations.length, 0);
        }
        function test_recent_default_rank_and_filters() {
            open();
            compare(launcher.results[0].title, "Kitty");
            compare(launcher.results[1].kind, "file");
            launcher.edit(":a ");
            compare(launcher.results.length, 3);
            compare(launcher.results[0].title, "Kitty");
            launcher.edit("file");
            compare(launcher.results.length, 1);
            compare(launcher.results[0].title, "Dolphin");
            launcher.removeFilter(false);
            launcher.edit(":c jutro");
            compare(launcher.results.length, 1);
            compare(launcher.results[0].id, "7");
            compare(Query.results("application", "kit", [{id: "hidden", name: "Kit", noDisplay: true}], [], [], []).length, 0);
        }
        function test_q_types_in_search_and_closes_results() {
            open();
            keyClick(Qt.Key_Q);
            compare(search().text, "q");
            verify(search().activeFocus);
            compare(preview.coordinator.activeId, "launcher");
            search().clear(); launcher.edit("");
            keyClick(Qt.Key_Escape);
            verify(list().activeFocus);
            keyClick(Qt.Key_Q);
            tryCompare(preview.coordinator, "activeId", "");
            compare(backend.activations.length, 0);
        }
        function test_escape_vim_enter_once_and_text_return() {
            open();
            keyClick(Qt.Key_Escape);
            verify(list().activeFocus);
            keyClick(Qt.Key_J); compare(loader.item.page.selectedIndex, 1);
            keyClick(Qt.Key_K); compare(loader.item.page.selectedIndex, 0);
            keyClick(Qt.Key_L); verify(search().activeFocus);
            keyClick(Qt.Key_Escape);
            keyClick(Qt.Key_Return);
            tryCompare(preview.coordinator, "activeId", "");
            compare(backend.activations.length, 1);
            compare(backend.activations[0].entry.id, "kitty");
            tryCompare(loader, "active", false);
            open(); keyClick(Qt.Key_Escape); keyClick(Qt.Key_Escape);
            compare(preview.coordinator.activeId, "");
        }
        function test_tab_mouse_clipboard_and_pending_failure() {
            open();
            type(":c ");
            keyClick(Qt.Key_Tab); verify(list().activeFocus);
            keyClick(Qt.Key_H); verify(chip().activeFocus);
            keyClick(Qt.Key_L); verify(search().activeFocus);
            backend.automatic = false;
            keyClick(Qt.Key_Return); keyClick(Qt.Key_Return);
            compare(backend.activations.length, 1);
            compare(backend.activations[0].entry.kind, "clipboard");
            backend.activated(launcher.request, "Odmowa");
            compare(launcher.lastError, "Odmowa");
            compare(preview.coordinator.activeId, "launcher");
            verify(!launcher.busy);
            backend.automatic = true;
            list().forceLayout();
            // The busy state also changes the outer layout; hit the rendered row.
            verify(waitForPolish(scene));
            verify(waitForRendering(list()));
            mouseClick(list().itemAtIndex(1));
            tryCompare(preview.coordinator, "activeId", "");
            compare(backend.activations.length, 2);
        }
        function test_debounce_stale_search_and_close_cancellation() {
            open(); backend.automatic = false;
            launcher.edit(":f first");
            wait(180);
            const old = launcher.revision;
            launcher.edit("second");
            backend.searched(old, ["/stale"], "");
            compare(launcher.files.length, 0);
            wait(180);
            backend.searched(launcher.revision, ["/second"], "");
            compare(launcher.results[0].id, "/second");
            launcher.edit("third");
            preview.coordinator.close(false);
            backend.searched(launcher.revision - 1, ["/stale"], "");
            verify(!launcher.active); verify(!backend.visible);
            compare(launcher.files.length, 0);
            compare(backend.searches[backend.searches.length - 1].query, "");
        }
        function test_async_results_keep_selected_identity() {
            open(); backend.automatic = false;
            launcher.edit("quickshell");
            wait(180);
            compare(launcher.results[0].kind, "clipboard");
            keyClick(Qt.Key_Escape);
            backend.searched(launcher.revision, ["/home/demo/quickshell.txt"], "");
            tryCompare(loader.item.page, "selectedIndex", 1);
            compare(launcher.results[1].kind, "clipboard");
            keyClick(Qt.Key_Return);
            compare(backend.activations[0].entry.kind, "clipboard");
            backend.activated(launcher.request, "");
        }
        function test_late_activation_cannot_close_reopened_panel() {
            open(); backend.automatic = false;
            keyClick(Qt.Key_Return);
            const request = launcher.request;
            preview.coordinator.close(false); tryCompare(loader, "active", false);
            open(); backend.activated(request, "");
            compare(preview.coordinator.activeId, "launcher");
            compare(activated.count, 0);
        }
        function test_monitor_handoff_invalidates_old_activation() {
            open(); backend.automatic = false;
            keyClick(Qt.Key_Return);
            const request = launcher.request;
            preview.coordinator.open("launcher", preview.secondScreen, null);
            backend.activated(request, "");
            compare(preview.coordinator.activeId, "launcher");
            compare(preview.coordinator.screenName, "TEST-2");
            compare(activated.count, 0);
        }
        function test_error_toast_beside_centered_launcher() {
            scene.width = 1920; scene.height = 1080;
            preview.notifications = notices;
            preview.errorNotificationsEnabled = true;
            notices.dnd = true;
            open();
            backend.clipboardError = "Schowek niedostępny";
            launcher.edit(":c ");
            tryVerify(() => preview.notificationStack !== null && preview.notificationStack.count > 0);
            verify(preview.notificationStack.x > loader.item.x + preview.panelHost.surfaceWidth
                || preview.notificationStack.y + preview.notificationStack.height < loader.item.y);
            verify(search().activeFocus);
            compare(preview.coordinator.activeId, "launcher");
        }
        function test_small_screen_and_last_result_reachable() {
            scene.width = 320; scene.height = 220;
            const previous = backend.clipboard;
            backend.clipboard = Array.from({length: 100}, (_, index) => ({id: String(index), preview: "Wpis " + index, binary: false}));
            open(); launcher.edit(":c ");
            verify(loader.item.width <= 304);
            verify(loader.item.height <= 172);
            keyClick(Qt.Key_Tab); keyClick(Qt.Key_End);
            compare(loader.item.page.selectedIndex, 99);
            tryVerify(() => list().contentY > 0);
            list().forceLayout();
            const last = list().itemAtIndex(99);
            verify(last !== null);
            verify(last.y + last.height <= list().contentY + list().height + 1);
            backend.clipboard = previous;
        }
        function test_exclusivity_monitor_hotplug_and_cycles() {
            open();
            verify(preview.coordinator.open("settings", preview.firstScreen, null));
            verify(!launcher.active); verify(!backend.visible);
            preview.coordinator.open("launcher", preview.secondScreen, null);
            compare(preview.panelHost.screen, preview.secondScreen);
            preview.coordinator.screens = [preview.firstScreen];
            compare(preview.coordinator.activeId, "");
            tryCompare(loader, "active", false);
            for (let i = 0; i < 20; i++) { open(); preview.coordinator.close(false); tryCompare(loader, "active", false); }
            compare(preview.createdCount, preview.destroyedCount);
        }
        function test_missing_backend_and_clipboard_are_not_empty_success() {
            backend.clipboardError = "Schowek niedostępny";
            open(); launcher.edit(":c ");
            compare(launcher.lastError, backend.clipboardError);
            backend.ready = false; backend.lastError = "Usługa niedostępna";
            compare(launcher.lastError, backend.lastError);
            keyClick(Qt.Key_Return);
            compare(backend.activations.length, 0);
        }
    }
}
