import QtQuick
import QtTest
import "../../core"
import "../../components" as UI

Rectangle {
    id: scene
    width: 420; height: 280
    color: "#101820"
    Component {
        id: panelComponent
        UI.FadeScope {
            readonly property bool accentScope: true
            property alias buttonText: button.text
            enabled: shown
            x: 30; y: 30; width: 340; height: 200
            Rectangle { anchors.fill: parent; color: Theme.backgroundStrong }
            UI.Button { id: button; objectName: "panelButton"; x: 20; y: 20; width: 300; height: 100; text: "Wi-Fi"; highlighted: true }
            UI.AccentRectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: Metrics.borderWidth
                accentOutline: true
            }
        }
    }
    Component {
        id: columnComponent
        UI.FadeColumn {
            x: 30; y: 30; width: 320; shown: true
            UI.Button { objectName: "columnButton"; width: parent.width; text: "Wi-Fi"; highlighted: true }
        }
    }
    TestCase {
        name: "Fade"
        when: windowShown
        function init() { failOnWarning(/.*/); }
        function test_layer_preserves_opaque_pixels_and_position() {
            // Transparent layers use grayscale text AA instead of the software
            // window's subpixel AA; compare frame/fill geometry without text.
            const panel = createTemporaryObject(panelComponent, scene, {buttonText: ""});
            tryCompare(panel, "opacity", 1);
            const layered = grabImage(scene);
            panel.layer.enabled = false;
            verify(waitForRendering(scene));
            const direct = grabImage(scene);
            for (let y = 20; y < 240; y += 3)
                for (let x = 20; x < 380; x += 3)
                    for (const channel of ["red", "green", "blue"])
                        verify(Math.abs(layered[channel](x, y) - direct[channel](x, y)) <= 3,
                            "Layer moved or changed pixels at " + x + "," + y);
        }
        function test_column_preserves_outer_focus_ring() {
            const column = createTemporaryObject(columnComponent, scene);
            const button = findChild(column, "columnButton");
            button.forceActiveFocus(Qt.TabFocusReason);
            tryCompare(column, "opacity", 1);
            const ring = findChild(button, "focusIndicator");
            verify(ring.visible);
            const origin = ring.mapToItem(scene, 0, 0);
            verify(origin.x < column.x && origin.y < column.y);
            const painted = grabImage(scene);
            const ratio = painted.width / scene.width;
            for (const point of [[1, 1], [ring.width - 2, 1], [1, ring.height - 2], [ring.width - 2, ring.height - 2]])
                verify(painted.pixel(Math.round((origin.x + point[0]) * ratio), Math.round((origin.y + point[1]) * ratio)) !== scene.color,
                    "Focus ring outside the column must remain painted");
            column.shown = false;
            tryCompare(column, "visible", false);
            verify(!column.composite.layer.enabled);
        }
        function test_waits_for_content_and_stable_layout() {
            const panel = createTemporaryObject(panelComponent, scene, {contentReady: false});
            verify(panel);
            wait(80);
            compare(panel.opacity, 0);
            panel.width = 320; panel.height = 180; panel.x = 40;
            panel.contentReady = true;
            compare(panel.opacity, 0);
            const geometry = [panel.x, panel.y, panel.width, panel.height];
            tryVerify(() => panel.opacity > 0 && panel.opacity < 1);
            while (panel.opacity < 1) {
                compare([panel.x, panel.y, panel.width, panel.height], geometry);
                wait(16);
            }
            verify(!panel.fadePresentation.preparation.running);
            panel.shown = false;
            wait(40);
            verify(panel.opacity > 0 && panel.opacity < 1);
            const closingOpacity = panel.opacity;
            panel.shown = true;
            compare(panel.opacity, closingOpacity);
            tryCompare(panel, "opacity", 1);
            panel.shown = false;
            tryCompare(panel, "visible", false);
            verify(!panel.layer.enabled);
            verify(!panel.fadePresentation.preparation.running);
            panel.shown = true;
            compare(panel.opacity, 0);
            tryCompare(panel, "opacity", 1);
        }
        function test_close_during_preparation_and_replace_content() {
            const panel = createTemporaryObject(panelComponent, scene, {contentReady: false});
            verify(panel);
            panel.shown = false;
            panel.contentReady = true;
            wait(80);
            compare(panel.opacity, 0);
            verify(!panel.fadePresentation.preparation.running);
            panel.shown = true;
            tryCompare(panel, "opacity", 1);
            panel.contentKey = "replacement";
            compare(panel.opacity, 0);
            panel.height = 190;
            tryCompare(panel, "opacity", 1);
        }
        function test_nested_content_enters_with_parent() {
            const panel = createTemporaryObject(panelComponent, scene, {contentReady: false});
            const nested = createTemporaryObject(panelComponent, panel, {x: 10, y: 10, width: 100, height: 100});
            verify(panel && nested);
            panel.contentReady = true;
            tryVerify(() => panel.opacity > 0 && panel.opacity < 1);
            compare(nested.opacity, 1);
            tryCompare(panel, "opacity", 1);
            nested.shown = false;
            wait(40);
            verify(nested.opacity > 0 && nested.opacity < 1);
            tryCompare(nested, "visible", false);
        }
        function test_group_pixels_data() {
            return [{tag: "quarter", alpha: 0.25}, {tag: "half", alpha: 0.5}, {tag: "three_quarters", alpha: 0.75}];
        }
        function test_exit_preserves_last_frame_data() {
            return [{tag: "panel", column: false}, {tag: "column", column: true}];
        }
        function test_exit_preserves_last_frame(data) {
            const item = createTemporaryObject(data.column ? columnComponent : panelComponent, scene);
            const button = findChild(item, data.column ? "columnButton" : "panelButton");
            button.forceActiveFocus(Qt.TabFocusReason);
            tryCompare(item, "opacity", 1);
            verify(findChild(button, "focusIndicator").visible);
            const opaque = grabImage(scene);
            item.shown = false;
            verify(!button.enabled, "Closing content must stop accepting input immediately");
            // Hold one exit frame while the disabled style and focus settle.
            item.opacity = 0.5;
            verify(waitForRendering(scene));
            const faded = grabImage(scene);
            const ratio = faded.width / scene.width;
            for (let y = 20; y < 240; y += 3) {
                for (let x = 20; x < 380; x += 3) {
                    const px = Math.round(x * ratio), py = Math.round(y * ratio);
                    for (const channel of ["red", "green", "blue"]) {
                        const background = channel === "red" ? 16 : channel === "green" ? 24 : 32;
                        const expected = (opaque[channel](px, py) + background) / 2;
                        verify(Math.abs(faded[channel](px, py) - expected) <= 3,
                            "Exit changed the composed image at " + x + "," + y + " " + channel);
                    }
                }
            }
        }
        function test_group_pixels(data) {
            const panel = createTemporaryObject(panelComponent, scene);
            verify(panel);
            tryCompare(panel, "opacity", 1);
            const opaque = grabImage(scene);
            panel.opacity = data.alpha;
            tryCompare(panel, "opacity", data.alpha);
            const faded = grabImage(scene);
            for (let y = 30; y < 230; y += 7) {
                for (let x = 30; x < 370; x += 7) {
                    for (const channel of ["red", "green", "blue"]) {
                        const background = channel === "red" ? 16 : channel === "green" ? 24 : 32;
                        const expected = opaque[channel](x, y) * data.alpha + background * (1 - data.alpha);
                        verify(Math.abs(faded[channel](x, y) - expected) <= 3,
                            "Composited fade at " + x + "," + y + " " + channel + ": " + faded[channel](x, y) + " vs " + expected);
                    }
                }
            }
        }
    }
}
