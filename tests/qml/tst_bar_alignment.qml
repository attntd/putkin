import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/bar"
import "../../components" as UI

Rectangle {
    id: scene
    // QtTest 6.11 paints physical pixels into an image sized in item units.
    // Leave room for the complete 800 px bar even at DPR 2, without clipping.
    width: 1600; height: 180
    color: Theme.background
    MockHyprland { id: desktop }
    WorkspaceService { id: workspaces; backend: desktop }
    MockBatteryBackend { id: backend }
    BatteryService { id: battery; backend: backend }
    BarView {
        id: bar
        width: 800; height: Metrics.barHeight
        service: workspaces; screenName: "TEST-1"
        battery: battery
        date: new Date(2026, 8, 16, 22, 57)
    }
    TestCase {
        name: "BarAlignment"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            backend.battery.state = 2;
            backend.battery.percentage = .72;
            mouseMove(scene, 10, 120);
        }
        function capture() {
            verify(waitForPolish(scene));
            return grabImage(scene);
        }
        function bounds(image, item, width) {
            const ratio = bar.Screen.devicePixelRatio;
            const origin = item.mapToItem(scene, 0, 0);
            verify((origin.x + item.width) * ratio <= image.width, "Physical capture must not be clipped");
            let minX = image.width, minY = image.height, maxX = -1, maxY = -1;
            for (let y = Math.ceil(origin.y * ratio); y < Math.floor((origin.y + item.height) * ratio); ++y)
                for (let x = Math.ceil(origin.x * ratio); x < Math.floor((origin.x + (width || item.width)) * ratio); ++x) {
                    const pixel = image.pixel(x, y);
                    if (pixel.r > .3 && pixel.g > .3 && pixel.b > .4) {
                        minX = Math.min(x, minX); minY = Math.min(y, minY);
                        maxX = Math.max(x, maxX); maxY = Math.max(y, maxY);
                    }
                }
            verify(maxX >= minX && maxY >= minY, "The icon/text must actually paint");
            return [minX, minY, maxX, maxY];
        }
        function test_equal_canvas_padding_above_separator() {
            for (const state of [2, 1]) {
                backend.battery.state = state;
                capture();
                for (const button of [bar.batteryButton, bar.quickSettingsButton]) {
                    const icon = button.contentItem as UI.Glyph;
                    const canvas = findChild(icon, "iconCanvas");
                    const position = canvas.mapToItem(bar, 0, 0);
                    compare(position.y, 5);
                    compare(bar.height - Metrics.borderWidth - position.y - canvas.height, 5);
                    compare(canvas.x, 6); compare(icon.width - canvas.x - canvas.width, 6);
                    compare(canvas.width, state === 1 && button === bar.batteryButton ? 24 : 20);
                    compare(canvas.height, 20);
                    compare(icon.iconVerticalPadding, 5);
                }
            }
        }
        function test_clock_visible_glyphs_are_centered_data() {
            const rows = [];
            for (const locale of ["pl_PL", "en_US"])
                for (const style of [0, 1, 2]) rows.push({tag: locale + style, locale: locale, style: style});
            return rows;
        }
        function test_clock_visible_glyphs_are_centered(data) {
            bar.clock.locale = Qt.locale(data.locale);
            bar.clock.dateStyle = data.style;
            const painted = bounds(capture(), bar.clock);
            const ratio = bar.Screen.devicePixelRatio;
            const bottom = Math.round(bar.contentHeight * ratio) - 1 - painted[3];
            verify(Math.abs(painted[1] - bottom) <= Math.ceil(ratio),
                "Uneven clock margins: " + painted[1] + "/" + bottom + " physical px");
        }
        function test_charging_material_body_height_and_wider_frame_data() {
            return [[0, "20"], [10, "20"], [25, "20"], [40, "30"], [55, "50"], [70, "60"], [85, "80"], [100, "full"]]
                .map(row => ({tag: String(row[0]), percent: row[0], variant: row[1]}));
        }
        function test_charging_material_body_height_and_wider_frame(data) {
            backend.battery.percentage = data.percent / 100;
            const icon = bar.batteryButton.contentItem as UI.Glyph;
            const normalSymbol = icon.symbol;
            const before = capture(), outerBefore = bounds(before, icon);
            const bodyBefore = bounds(before, icon, 20);
            compare(bar.batteryButton.width, 32);
            backend.battery.state = 1;
            compare(icon.symbol, "battery_charging_" + data.variant + "_2");
            const after = capture();
            const outerAfter = bounds(after, icon), bodyAfter = bounds(after, icon, 20);
            compare(bar.batteryButton.width, 36);
            compare(outerAfter[1], outerBefore[1]); compare(outerAfter[3], outerBefore[3]);
            // Compare the left-hand battery body, excluding the bolt on the right.
            compare(bodyAfter[1], bodyBefore[1]); compare(bodyAfter[3], bodyBefore[3]);
            verify(outerAfter[2] - outerAfter[0] > outerBefore[2] - outerBefore[0],
                "The original external bolt must receive more horizontal room");
            const origin = icon.mapToItem(scene, 0, 0), ratio = icon.pixelRatio;
            verify(outerAfter[2] > (origin.x + 24) * ratio, "Missing external bolt on the right");
            verify(outerAfter[2] < (origin.x + icon.width - 6) * ratio, "Clipped charging icon");
            backend.battery.state = 2;
            compare(icon.symbol, normalSymbol);
            const restored = capture();
            compare(bar.batteryButton.width, 32);
            compare(bounds(restored, icon), outerBefore);
        }
    }
}
