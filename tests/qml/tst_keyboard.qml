import QtQuick
import QtTest
import "../../core"
import "../../core/Actions.js" as Actions
import "../../core/Appearance.js" as Appearance
import "../../services"
import "../../preview"

Item {
    id: scene
    width: 1000
    height: 900
    MockSettingsFile { id: file }
    MockKeyboardBackend { id: backend }
    KeyboardSettings { id: keyboard; storage: file; backend: backend }
    MockSettingsFile { id: appearanceFile }
    Settings { id: settings; storage: appearanceFile; keyboard: keyboard }
    MockLauncherBackend { id: launcherBackend }
    LauncherService { id: launcher; backend: launcherBackend; workspaceService: preview.workspaceService; keyboard: keyboard; actions: actions }
    QtObject {
        id: windowActions
        property string lastError: ""
        property var calls: []
        function invoke(action: string, window: var, monitor: string): bool {
            calls = calls.concat([{action: action, address: window.address, monitor: monitor}]);
            return true;
        }
    }
    MockAudioBackend { id: pipewire }
    AudioService { id: audio; backend: pipewire }
    MockBrightnessBackend { id: backlight }
    BrightnessService { id: brightness; backend: backlight }
    MockSessionBackend { id: sessionBackend }
    SessionService { id: session; backend: sessionBackend }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notifications; backend: notificationBackend; screens: preview.coordinator.screens; monitorService: preview.backend }
    NotificationFocus { id: notificationFocus; service: notifications; panels: preview.coordinator; barFocus: preview.barController }
    ActionController {
        id: actions
        coordinator: preview.coordinator; launcher: launcher; hyprland: preview.workspaceService; windowActions: windowActions
        barFocus: preview.barController; notificationFocus: notificationFocus; notifications: notifications
        audio: audio; brightness: brightness; sessionService: session
    }
    QtObject {
        id: loader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader { active: loader.activeAsync; asynchronous: true; sourceComponent: preview.panelComponent }
    }
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: loader; settings: settings; launcher: launcher; audio: audio; notifications: notifications }
    TestCase {
        name: "Keyboard"
        when: windowShown
        function control(name) { return findChild(loader.item, name); }
        function init() {
            failOnWarning(/.*/);
            preview.coordinator.close(false); tryCompare(loader, "active", false);
            file.pending = null; file.autoComplete = true; file.writes = 0;
            file.snapshot = Appearance.observation("", true, "");
            backend.autoComplete = true; backend.checkError = ""; backend.lastError = "";
            keyboard.cancelEdit(); windowActions.calls = [];
            preview.backend.reset(); scene.width = 1000; scene.height = 900;
        }
        function cleanup() { preview.coordinator.close(false); tryCompare(loader, "active", false); }
        function openKeyboard() {
            verify(preview.coordinator.open("settings", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => control("keyboardSection") !== null);
            tryVerify(() => control("backButton").activeFocus);
            tryCompare(loader.item, "opacity", 1);
            control("keyboardSection").forceActiveFocus(); keyClick(Qt.Key_Return);
            tryVerify(() => control("keyboardActions") !== null);
        }
        function type(text) { for (const letter of text) keyClick(letter); }
        function saveAlias(action, command) {
            keyboard.beginEdit(); keyboard.setBinding(action, "command", command);
            verify(keyboard.save()); tryCompare(keyboard, "saving", false);
            compare(keyboard.problem, ""); keyboard.cancelEdit();
        }
        function test_ui_keyboard_navigation_save_and_reopen() {
            openKeyboard();
            keyClick(Qt.Key_J); verify(control("keyboardActions").activeFocus);
            keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            verify(control("shortcutField").activeFocus);
            keyClick(Qt.Key_A, Qt.ControlModifier); type("SUPER + ALT + V");
            keyClick(Qt.Key_Return); verify(control("commandField").activeFocus);
            type(":schowek"); keyClick(Qt.Key_Return);
            verify(control("saveKeyboardButton").activeFocus); keyClick(Qt.Key_Return);
            tryCompare(keyboard, "saving", false);
            compare(file.writes, 1);
            compare(keyboard.command(":schowek").action, "clipboard");
            compare(backend.applied.find(row => row.action === "clipboard").shortcut, "SUPER + ALT + V");
            preview.coordinator.close(false); tryCompare(loader, "active", false);
            openKeyboard();
            keyClick(Qt.Key_J); keyClick(Qt.Key_J); keyClick(Qt.Key_Return);
            compare(control("commandField").text, ":schowek");
            compare(control("shortcutField").text, "SUPER + ALT + V");
        }
        function test_text_letters_and_draft_across_sections() {
            openKeyboard(); control("commandField").forceActiveFocus(); type(":hjkl");
            compare(control("commandField").text, ":hjkl");
            control("appearanceSection").click();
            tryVerify(() => control("accentPreset1") !== null); control("accentPreset1").click();
            control("keyboardSection").click();
            tryVerify(() => control("commandField") !== null);
            compare(control("commandField").text, ":hjkl");
            preview.coordinator.close(false);
            compare(keyboard.command(":hjkl"), null); compare(file.writes, 0);
            verify(!settings.editing); verify(!keyboard.editing);
        }
        function test_duplicate_and_reserved_commands_do_not_write() {
            compare(Actions.shortcut("Super + :"), "SUPER + SHIFT + semicolon");
            compare(Actions.shortcut("Super + Shift + ;"), "SUPER + SHIFT + semicolon");
            keyboard.beginEdit();
            keyboard.setBinding("settings", "shortcut", "super + v");
            verify(!keyboard.canSave); verify(!keyboard.save());
            keyboard.setBinding("settings", "shortcut", "");
            for (const command of [":w", ":w3", ":mw0", ":a", "bad", ":bad space", ":a;exit"]) {
                keyboard.setBinding("settings", "command", command);
                verify(!keyboard.canSave, command); verify(!keyboard.save());
            }
            keyboard.setBinding("settings", "command", ":audio");
            keyboard.setBinding("audio", "command", ":AUDIO");
            verify(!keyboard.canSave); compare(file.writes, 0);
        }
        function test_compositor_conflict_and_write_failure() {
            keyboard.beginEdit(); keyboard.setBinding("settings", "shortcut", "SUPER + C");
            backend.checkError = "Konflikt skrótu: Close";
            verify(keyboard.save()); tryCompare(keyboard, "saving", false);
            compare(keyboard.saveProblem, backend.checkError); compare(file.writes, 0);
            backend.checkError = ""; file.autoComplete = false;
            verify(keyboard.save()); tryVerify(() => file.pending !== null);
            file.pending = null; file.failed("write");
            verify(!keyboard.saving); verify(keyboard.saveProblem.length > 0);
            compare(keyboard.persisted.find(row => row.action === "settings").shortcut, "");
        }
        function test_external_change_and_late_validation_cannot_save_closed_editor() {
            keyboard.beginEdit(); keyboard.setBinding("settings", "command", ":settings");
            backend.autoComplete = false; verify(keyboard.save()); const old = keyboard.checkGeneration;
            keyboard.cancelEdit(); keyboard.beginEdit(); keyboard.setBinding("audio", "command", ":audio");
            verify(keyboard.save()); backend.checked(old, ""); compare(file.writes, 0); verify(keyboard.checking);
            const external = Actions.defaults(); external[0].command = ":launch";
            file.external(Actions.serialize(external)); verify(keyboard.conflict);
            backend.checked(keyboard.checkGeneration, ""); tryCompare(keyboard, "saving", false);
            compare(file.writes, 0); verify(keyboard.conflict);
            keyboard.useLatest(); compare(keyboard.draft[0].command, ":launch");
        }
        function test_future_schema_preserved_and_backend_reload() {
            file.external('{"schemaVersion":2,"bindings":[]}'); keyboard.beginEdit();
            verify(!keyboard.canSave); verify(keyboard.readProblem.length > 0); compare(file.writes, 0);
            file.snapshot = Appearance.observation("", true, ""); keyboard.useLatest();
            backend.applied = []; backend.reloaded(); compare(backend.applied, keyboard.persisted);
        }
        function test_command_chip_alias_and_panel_handoff() {
            saveAlias("settings", ":ustawienia");
            preview.coordinator.open("launcher", preview.firstScreen, null); tryCompare(loader, "active", true);
            launcher.startMode("commands");
            tryVerify(() => control("launcherSearch") && control("launcherSearch").activeFocus);
            compare(control("launcherChip").text, "Komenda"); compare(control("launcherSearch").text, "");
            compare(control("launcherChip").trailingIcon, "close");
            type("ustawienia"); compare(launcher.results.length, 1);
            compare(preview.coordinator.activeId, "launcher"); keyClick(Qt.Key_Return);
            tryCompare(preview.coordinator, "activeId", "settings"); tryCompare(loader, "active", true);
            tryVerify(() => control("backButton") && control("backButton").activeFocus);
        }
        function test_command_captures_window_and_clear_chip() {
            saveAlias("floating", ":float");
            preview.coordinator.open("launcher", preview.firstScreen, null); tryCompare(loader, "active", true);
            launcher.startMode("commands");
            preview.backend.activeWindow = preview.backend.secondWindow;
            launcher.edit("float"); verify(launcher.activate(launcher.results[0]));
            compare(windowActions.calls, [{action: "floating", address: "0x123", monitor: "TEST-1"}]);
            preview.coordinator.open("launcher", preview.firstScreen, null); tryCompare(loader, "active", true);
            launcher.startMode("commands"); control("launcherChip").click();
            compare(launcher.chipMode, ""); verify(!launcher.commandInput);
            launcher.edit(":float"); compare(launcher.results[0].action, "floating");
        }
        function test_actions_route_to_shared_services() {
            verify(actions.invoke("volumeDown", null, "TEST-1")); tryCompare(audio, "busy", false);
            verify(actions.invoke("micMute", null, "TEST-1")); tryCompare(audio.microphone, "busy", false);
            verify(audio.microphone.muted);
            const previous = notifications.dnd; verify(actions.invoke("dnd", null, "TEST-1")); compare(notifications.dnd, !previous);
            verify(!actions.invoke("exec", null, "TEST-1")); verify(actions.lastError.length > 0);
        }
        function test_small_window_keeps_list_and_editor_focus_visible() {
            scene.width = 320; scene.height = 220;
            openKeyboard(); keyClick(Qt.Key_J);
            const list = control("keyboardActions"); verify(list.activeFocus);
            const viewport = loader.item.viewport;
            const position = list.mapToItem(viewport, 0, 0);
            verify(position.y >= 0 && position.y + list.height <= viewport.height);
            for (let i = 1; i < keyboard.catalog.length; ++i) keyClick(Qt.Key_J);
            compare(list.currentIndex, keyboard.catalog.length - 1);
            keyClick(Qt.Key_Return); verify(control("shortcutField").activeFocus);
            const field = control("shortcutField").mapToItem(viewport, 0, 0);
            verify(field.y >= 0 && field.y + control("shortcutField").height <= viewport.height);
            keyClick(Qt.Key_Return); type(":last"); keyClick(Qt.Key_Return); keyClick(Qt.Key_Return);
            tryCompare(keyboard, "saving", false);
            compare(keyboard.command(":last").action, "moveWorkspace10");
        }
    }
}
