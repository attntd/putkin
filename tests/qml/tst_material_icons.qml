import QtQuick
import QtTest
import "../../core"
import "../../components" as UI
import "../../assets/material/Paths.js" as Paths
import "IconPixels.js" as Pixels

Rectangle {
    id: scene
    width: 500; height: 300
    color: Theme.background
    UI.Glyph { id: icon; x: 40; y: 40; section: "bar"; symbol: "notifications" }
    TestCase {
        name: "MaterialIcons"
        when: windowShown
        function init() { failOnWarning(/.*/); icon.color = Theme.text; }
        function test_all_vectors_paint_one_color_data() {
            return Object.keys(Paths.icons).map(name => ({tag: name, symbol: name}));
        }
        function test_all_vectors_paint_one_color(data) {
            icon.symbol = data.symbol;
            icon.section = "bar";
            Pixels.verifyIcon(this, scene, icon, scene.color);
        }
        function test_sections_keep_canvas_padding_and_center_data() {
            return Object.keys(Metrics.iconSections).map(section => ({tag: section, section: section}));
        }
        function test_sections_keep_canvas_padding_and_center(data) {
            icon.section = data.section;
            const size = Metrics.iconSections[data.section].size;
            const padding = Metrics.iconSections[data.section].padding;
            const vertical = icon.iconVerticalPadding;
            for (const name of ["network_wifi", "bluetooth", "volume_up", "battery_android_3", "putkin_tether", "chat_bubble"]) {
                icon.symbol = name;
                const canvas = findChild(icon, "iconCanvas");
                compare(icon.width, size + 2 * padding); compare(icon.height, size + 2 * vertical);
                compare(canvas.width, size); compare(canvas.height, size);
                compare(canvas.x, padding); compare(canvas.y, vertical);
                Pixels.verifyIcon(this, scene, icon, scene.color);
            }
        }
        function test_color_changes_do_not_change_geometry() {
            icon.section = "bar"; icon.symbol = "notifications_unread";
            for (const color of [Theme.text, Theme.warning, Theme.accent]) {
                icon.color = color;
                Pixels.verifyIcon(this, scene, icon, scene.color);
                compare(icon.width, 32); compare(icon.height, 30);
            }
        }
    }
}
