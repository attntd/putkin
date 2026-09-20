import QtQuick
import QtTest
import "../../core"
import "../../core/Appearance.js" as Appearance
import "../../preview"
import "../../modules/bar"
import "../../components" as UI

Item {
    id: scene
    width: 1000
    height: 900
    MockSettingsFile { id: file }
    Settings { id: settings; storage: file }
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
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: testLoader; settings: settings }
    BarView {
        id: secondBar
        width: 400
        height: Metrics.barHeight
        y: 60
        screenName: "TEST-2"
        service: preview.bar.service
        date: preview.date
    }
    UI.Slider { id: secondarySlider; y: 120; accessibleName: "Test"; fillColor: Theme.accentSecondary }

    TestCase {
        name: "Settings"
        when: windowShown
        readonly property var coordinator: preview.coordinator
        readonly property var host: preview.panelHost
        function init() {
            failOnWarning(/.*/);
            coordinator.close(false);
            tryCompare(host, "loaded", false);
            file.pending = null;
            file.autoComplete = true;
            file.writes = 0;
            file.snapshot = Appearance.observation("", true, "");
            settings.cancelEdit();
            coordinator.screens = [preview.firstScreen, preview.secondScreen];
            scene.width = 1000;
            scene.height = 900;
        }
        function cleanup() { coordinator.close(false); tryCompare(host, "loaded", false); }
        function control(name) { return findChild(host.window, name); }
        function open() {
            verify(coordinator.open("settings", preview.firstScreen, null));
            tryCompare(host, "loaded", true);
            tryVerify(() => control("backButton") && control("backButton").activeFocus);
        }
        function focusControl(name) { control(name).forceActiveFocus(Qt.TabFocusReason); }
        function type(value) {
            keyClick(Qt.Key_A, Qt.ControlModifier);
            for (const letter of value) keyClick(letter);
        }
        function test_defaults_and_schema_validation_data() {
            return [
                {tag: "optional appearance", text: '{"schemaVersion":1}', ok: true},
                {tag: "optional colors", text: '{"schemaVersion":1,"appearance":{}}', ok: true},
                {tag: "valid", text: Appearance.serialize({accent:"#ABCDEF",accentSecondary:"#000000"}), ok:true},
                {tag: "legacy motion enabled", text: '{"schemaVersion":1,"appearance":{"reducedMotion":true}}', ok:true},
                {tag: "legacy motion disabled", text: '{"schemaVersion":1,"appearance":{"reducedMotion":false}}', ok:true},
                {tag: "malformed", text: '{', ok:false},
                {tag: "null", text: 'null', ok:false},
                {tag: "array", text: '[]', ok:false},
                {tag: "missing version", text: '{}', ok:false},
                {tag: "future", text: '{"schemaVersion":2}', ok:false},
                {tag: "old", text: '{"schemaVersion":0}', ok:false},
                {tag: "string version", text: '{"schemaVersion":"1"}', ok:false},
                {tag: "short color", text: '{"schemaVersion":1,"appearance":{"accent":"#abc"}}', ok:false},
                {tag: "transparent", text: '{"schemaVersion":1,"appearance":{"accent":"#00abcdef"}}', ok:false},
                {tag: "named color", text: '{"schemaVersion":1,"appearance":{"accentSecondary":"red"}}', ok:false},
                {tag: "null appearance", text: '{"schemaVersion":1,"appearance":null}', ok:false},
                {tag: "boolean type", text: '{"schemaVersion":1,"appearance":{"reducedMotion":"false"}}', ok:false},
                {tag: "unknown option", text: '{"schemaVersion":1,"appearance":{"future":true}}', ok:false}
            ];
        }
        function test_defaults_and_schema_validation(data) {
            file.external(data.text);
            open();
            compare(settings.readProblem.length === 0, data.ok);
            compare(settings.canSave, data.ok);
            if (!data.ok) { verify(!settings.save()); compare(file.writes, 0); }
        }
        function test_presets_navigation_and_live_controls() {
            open();
            keyClick(Qt.Key_J);
            verify(control("appearanceSection").activeFocus);
            keyClick(Qt.Key_J);
            verify(control("accentPreset0").activeFocus);
            keyClick(Qt.Key_L);
            verify(control("accentPreset1").activeFocus);
            keyClick(Qt.Key_Enter, Qt.KeypadModifier);
            compare(Theme.accent, "#f5c2e7");
            compare(settings.persisted.appearance.accent, "#cba6f7");
            compare(control("accentPreset1").trailingIcon, "check");
            keyClick(Qt.Key_J);
            verify(control("accentPreset4").activeFocus);
            keyClick(Qt.Key_H);
            verify(control("accentPreset3").activeFocus);
            keyClick(Qt.Key_K);
            verify(control("accentPreset0").activeFocus);
            for (const key of ["accent", "accentSecondary"]) {
                for (let i = 0; i < 6; ++i) {
                    const button = control(key + "Preset" + i);
                    button.forceActiveFocus(Qt.TabFocusReason);
                    mouseClick(button);
                    compare(settings.effective[key], Appearance.presets[i].color);
                }
            }
            compare(preview.bar.quickSettingsButton.fillColor, Theme.accent);
            compare(secondarySlider.fillColor, Theme.accentSecondary);
            compare(((secondBar.workspaces.list.itemAtIndex(1) as WorkspaceButton).background as Rectangle).color, Theme.accent);
            compare(file.writes, 0);
        }
        function test_hex_validation_keeps_letters_and_visible_focus() {
            open();
            focusControl("accentField");
            type("hjkl");
            compare(control("accentField").text, "hjkl");
            verify(control("accentField").activeFocus);
            verify(control("accentField").invalid);
            compare(control("accentError"), null);
            verify(!control("saveSettingsButton").enabled);
            compare(Theme.accent, "#cba6f7");
            type("#012345");
            compare(Theme.accent, "#012345");
            verify(!control("accentField").invalid);
            verify(findChild(control("accentField"), "focusIndicator").visible);
            keyClick(Qt.Key_Return);
            verify(control("accentSecondaryPreset0").activeFocus);
            focusControl("accentSecondaryField");
            type("#FFFFFF");
            compare(Theme.accentSecondary, "#ffffff");
            compare(file.writes, 0);
        }
        function test_all_dismissal_routes_discard_preview_data() {
            return ["cancel", "close", "escape", "back", "replace", "monitor", "hotplug", "bar", "early"].map(tag => ({tag:tag}));
        }
        function test_all_dismissal_routes_discard_preview(data) {
            if (data.tag === "early") coordinator.open("settings", preview.firstScreen, null);
            else open();
            settings.setColor("accent", "#abcdef");
            settings.setColor("accentSecondary", "#123456");
            compare(Theme.accent, "#abcdef");
            if (data.tag === "cancel" || data.tag === "close" || data.tag === "back") {
                focusControl(data.tag === "cancel" ? "cancelSettingsButton" : data.tag === "close" ? "closeButton" : "backButton");
                keyClick(Qt.Key_Return);
            } else if (data.tag === "escape") keyClick(Qt.Key_Escape);
            else if (data.tag === "replace") coordinator.open("quickSettings", preview.firstScreen, null);
            else if (data.tag === "monitor") coordinator.open("settings", preview.secondScreen, null);
            else if (data.tag === "hotplug") coordinator.screens = [preview.secondScreen];
            else if (data.tag === "bar") preview.barController.focusBar();
            else coordinator.close(false);
            compare(Theme.accent, "#cba6f7");
            compare(Theme.accentSecondary, "#89b4fa");
            compare(file.writes, 0);
        }
        function test_settings_remain_open_when_desktop_is_clicked() {
            open(); settings.setColor("accent", "#abcdef");
            mouseClick(preview, 20, 400);
            compare(coordinator.activeId, "settings");
            compare(settings.draft.accent, "#abcdef");
            verify(settings.editing);
        }
        function test_save_is_confirmed_reset_is_only_a_draft_and_retry() {
            open();
            file.autoComplete = false;
            focusControl("accentField"); type("#010101");
            focusControl("saveSettingsButton"); keyClick(Qt.Key_Return);
            verify(settings.saving);
            compare(settings.notice, "");
            compare(settings.persisted.appearance.accent, "#cba6f7");
            file.pending = null;
            file.failed("write");
            verify(!settings.saving);
            verify(settings.saveProblem.length > 0);
            compare(settings.persisted.appearance.accent, "#cba6f7");
            verify(settings.save());
            file.complete();
            compare(settings.persisted.appearance.accent, "#010101");
            compare(settings.notice, "Zapisano ustawienia.");
            focusControl("resetButton"); keyClick(Qt.Key_Space);
            compare(Theme.accent, "#cba6f7");
            compare(settings.persisted.appearance.accent, "#010101");
            compare(file.writes, 1);
            keyClick(Qt.Key_Escape);
            compare(Theme.accent, "#010101");
        }
        function test_external_changes_keep_draft_panel_cursor_and_focus_twenty_times() {
            open();
            focusControl("accentField"); type("#123456");
            const window = host.window, page = window.page, field = control("accentField");
            const position = field.cursorPosition;
            for (let i = 0; i < 20; ++i) {
                file.external(Appearance.serialize({accent: i % 2 ? "#fab387" : "#94e2d5", accentSecondary:"#89b4fa"}));
                file.refresh();
                compare(host.window, window);
                compare(window.page, page);
                compare(control("accentField"), field);
                verify(field.activeFocus);
                compare(field.cursorPosition, position);
                compare(field.text, "#123456");
                compare(Theme.accent, "#123456");
                verify(settings.conflict);
                verify(!settings.canSave);
            }
            focusControl("reloadSettingsButton"); keyClick(Qt.Key_Return);
            compare(Theme.accent, "#fab387");
            verify(!settings.conflict);
            compare(field.text, "#fab387");
            compare(file.writes, 0);
        }
        function test_corrupt_file_preserves_last_good_state_and_future_version_is_read_only() {
            file.external(Appearance.serialize({accent:"#abcdef", accentSecondary:"#123456"}));
            file.external("{");
            compare(Theme.accent, "#abcdef");
            open();
            verify(settings.readProblem.length > 0);
            verify(!settings.save());
            file.external('{"schemaVersion":9,"appearance":{"future":true}}');
            settings.useLatest();
            settings.resetDraft();
            verify(!settings.save());
            compare(file.writes, 0);
            coordinator.close(false);
            compare(Theme.accent, "#abcdef");
        }
        function test_contrast_and_navigation_without_motion_option() {
            open();
            const semantic = [String(Theme.success), String(Theme.warning), String(Theme.error)];
            for (const color of ["#000000", "#010101", "#1e1e2e", "#777777", "#ffffff"]) {
                settings.setColor("accent", color);
                settings.setColor("accentSecondary", color);
                verify(Appearance.contrast(color, String(Theme.accentText)) >= 4.5);
                verify(Appearance.contrast(color, String(Theme.accentSecondaryText)) >= 4.5);
                verify(Appearance.contrast(String(Theme.focus), String(Theme.backgroundStrong)) >= 3);
                compare([String(Theme.success), String(Theme.warning), String(Theme.error)], semantic);
            }
            compare(control("reducedMotionButton"), null);
            focusControl("accentSecondaryField"); keyClick(Qt.Key_Return);
            verify(control("resetButton").activeFocus);
            keyClick(Qt.Key_K);
            verify(control("accentSecondaryField").activeFocus);
            keyClick(Qt.Key_Tab);
            verify(control("resetButton").activeFocus);
            verify(settings.save());
            tryCompare(settings, "saving", false);
            coordinator.close(false);
            tryCompare(host, "loaded", false);
        }
        function test_legacy_motion_is_ignored_and_removed_only_on_save_data() {
            return [{tag: "enabled", value: true}, {tag: "disabled", value: false}];
        }
        function test_legacy_motion_is_ignored_and_removed_only_on_save(data) {
            const old = JSON.stringify({schemaVersion: 1, appearance: {accent: "#abcdef", accentSecondary: "#123456", reducedMotion: data.value}});
            file.external(old);
            compare(settings.persisted.appearance, {accent: "#abcdef", accentSecondary: "#123456"});
            open();
            compare(file.writes, 0);
            compare(file.snapshot.text, old);
            verify(settings.save());
            tryCompare(settings, "saving", false);
            compare(JSON.parse(file.snapshot.text), {schemaVersion: 1, appearance: {accent: "#abcdef", accentSecondary: "#123456"}});
        }
        function test_disabled_save_is_skipped_with_vim_and_tab() {
            open();
            focusControl("accentField"); type("bad");
            focusControl("resetButton"); keyClick(Qt.Key_J);
            verify(control("cancelSettingsButton").activeFocus);
            keyClick(Qt.Key_Backtab);
            verify(control("resetButton").activeFocus);
            keyClick(Qt.Key_Tab);
            verify(control("cancelSettingsButton").activeFocus);
        }
    }
}
