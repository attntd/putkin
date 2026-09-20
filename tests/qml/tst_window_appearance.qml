import QtQuick
import QtTest
import "../../core"
import "../../core/Appearance.js" as Appearance
import "../../preview"
import "../../services"

Item {
    MockSettingsFile { id: file }
    Settings { id: settings; storage: file }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    QtObject {
        id: backend
        property bool ready: false
        property var calls: []
        signal reloaded()
        function apply(primary, secondary, inactive, width, radius) {
            calls = calls.concat([{primary: String(primary), secondary: String(secondary),
                inactive: String(inactive), width: width, radius: radius}]);
        }
    }
    WindowAppearanceService { id: service; backend: backend }
    TestCase {
        name: "WindowAppearance"
        when: windowShown
        function init() {
            failOnWarning(/.*/);
            backend.ready = false;
            settings.cancelEdit();
            file.external(Appearance.serialize(Appearance.defaults().appearance));
            wait(1);
            backend.calls = [];
        }
        function applied(primary, secondary) {
            tryVerify(() => backend.calls.length > 0 && backend.calls[backend.calls.length - 1].primary === primary
                && backend.calls[backend.calls.length - 1].secondary === secondary);
            const last = backend.calls[backend.calls.length - 1];
            compare(last.inactive, "#45475a");
            compare(last.width, 2);
            compare(last.radius, 0);
        }
        function test_waits_for_backend_and_deduplicates() {
            compare(backend.calls.length, 0);
            backend.ready = true;
            applied("#cba6f7", "#89b4fa");
            const count = backend.calls.length;
            service.apply();
            wait(20);
            compare(backend.calls.length, count);
        }
        function test_preview_cancel_and_save() {
            backend.ready = true;
            applied("#cba6f7", "#89b4fa");
            settings.beginEdit();
            settings.setColor("accent", "#94e2d5");
            settings.setColor("accentSecondary", "#fab387");
            applied("#94e2d5", "#fab387");
            settings.cancelEdit();
            applied("#cba6f7", "#89b4fa");
            settings.beginEdit();
            settings.setColor("accent", "#94e2d5");
            verify(settings.save());
            tryCompare(settings, "saving", false);
            settings.cancelEdit();
            applied("#94e2d5", "#89b4fa");
        }
        function test_reload_and_reconnect_reapply() {
            backend.ready = true;
            applied("#cba6f7", "#89b4fa");
            const count = backend.calls.length;
            backend.reloaded();
            tryVerify(() => backend.calls.length === count + 1);
            backend.ready = false;
            wait(1);
            backend.ready = true;
            tryVerify(() => backend.calls.length === count + 2);
        }
        function test_external_settings_and_invalid_file() {
            backend.ready = true;
            file.external(Appearance.serialize({accent: "#f5c2e7", accentSecondary: "#94e2d5"}));
            applied("#f5c2e7", "#94e2d5");
            file.external("{");
            wait(1);
            applied("#f5c2e7", "#94e2d5");
        }
        function test_contrast_matches_shell_border() {
            backend.ready = true;
            settings.beginEdit();
            settings.setColor("accent", "#181825");
            settings.setColor("accentSecondary", "#000000");
            applied("#cdd6f4", "#cdd6f4");
        }
    }
}
