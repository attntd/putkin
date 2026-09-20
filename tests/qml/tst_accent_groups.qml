import QtQuick
import QtTest
import "../../components" as UI
import "../../core"

Item {
    id: scene
    width: 640; height: 420
    Item {
        id: group
        readonly property bool accentScope: true
        x: 20; y: 20; width: 240; height: 160
        UI.AccentRectangle { id: frame; anchors.fill: parent; color: Theme.backgroundStrong; border.width: 2; accentOutline: true }
        UI.AccentRectangle { id: first; x: 12; y: 12; width: 90; height: 40; color: Theme.accent; accentFill: true }
        UI.AccentRectangle { id: second; x: 128; y: 12; width: 90; height: 40; color: Theme.accent; accentFill: true }
        Flickable {
            id: scroll
            x: 12; y: 70; width: 206; height: 60; contentHeight: 200; clip: true
            UI.AccentRectangle {
                id: scrollingTile
                readonly property bool accentScope: true
                y: 50; width: 206; height: 80; color: Theme.accent; accentFill: true
            }
        }
    }
    Item {
        id: otherGroup
        readonly property bool accentScope: true
        x: 300; y: 210; width: 240; height: 160
        UI.AccentRectangle { id: other; x: 12; y: 12; width: 90; height: 40; color: Theme.accent; accentFill: true }
    }
    TestCase {
        name: "AccentGroups"
        when: windowShown
        property var previousAppearance
        function init() {
            failOnWarning(/.*/);
            previousAppearance = Theme.appearance;
            Theme.appearance = {accent: "#f08090", accentSecondary: "#80c0f0"};
            group.width = 240; group.height = 160; second.x = 128; scroll.contentY = 0;
        }
        function cleanup() { Theme.appearance = previousAppearance; }
        function expected(x, y, width, height) {
            const t = Math.max(0, Math.min(1, (x / width + y / height) / 2));
            return [240 + (128 - 240) * t, 128 + (192 - 128) * t, 144 + (240 - 144) * t];
        }
        function pixel(image, x, y, value) {
            fuzzyCompare(image.red(x, y), value[0], 2);
            fuzzyCompare(image.green(x, y), value[1], 2);
            fuzzyCompare(image.blue(x, y), value[2], 2);
        }
        function test_one_diagonal_field_across_controls_and_frame() {
            verify(waitForRendering(group));
            const image = grabImage(group);
            for (const point of [[1, 1], [238, 158], [20, 20], [140, 20], [90, 45], [210, 45]])
                pixel(image, point[0], point[1], expected(point[0] + .5, point[1] + .5, group.width, group.height));
            verify(image.red(20, 20) > image.red(140, 20), "Gradient must not restart in the second tile");
            const lower = image.blue(1, 158), upper = image.blue(1, 1);
            verify(lower > upper + 15, "Gradient must also progress downwards");
        }
        function test_each_group_has_its_own_origin() {
            verify(waitForRendering(scene));
            const image = grabImage(scene);
            const a = first.mapToItem(scene, 20, 20), b = other.mapToItem(scene, 20, 20);
            compare(image.pixel(a.x, a.y), image.pixel(b.x, b.y));
        }
        function test_wide_group_keeps_vertical_color_progression() {
            group.width = 520; group.height = 32;
            verify(waitForPolish(scene)); verify(waitForRendering(scene));
            const image = grabImage(group);
            for (const point of [[1, 1], [518, 1], [1, 30], [518, 30], [260, 1], [260, 30]])
                pixel(image, point[0], point[1], expected(point[0] + .5, point[1] + .5, group.width, group.height));
            verify(image.red(260, 1) - image.red(260, 30) > 45,
                "A wide group must retain the full vertical share of the diagonal");
        }
        function test_resize_move_and_scroll_update_shared_coordinates() {
            group.width = 300; group.height = 190; second.x = 180; scroll.contentY = 50;
            verify(waitForPolish(scene)); verify(waitForRendering(scene));
            const image = grabImage(group);
            for (const point of [[200, 20], [40, 80], [290, 1]])
                pixel(image, point[0], point[1], expected(point[0] + .5, point[1] + .5, group.width, group.height));
        }
        function test_live_palette_change_and_outline_contrast() {
            Theme.appearance = {accent: "#80c0f0", accentSecondary: "#f08090"};
            verify(waitForRendering(group));
            const image = grabImage(group);
            verify(image.red(20, 20) < image.red(140, 20));
            Theme.appearance = {accent: "#181825", accentSecondary: "#010101"};
            verify(waitForRendering(group));
            compare(grabImage(group).pixel(1, 1), Theme.text);
        }
    }
}
