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
    MockNetworkBackend { id: networkBackend }
    NetworkService { id: network; backend: networkBackend }
    MockBluetoothBackend { id: bluetoothBackend }
    BluetoothService { id: bluetooth; backend: bluetoothBackend }
    MockBatteryBackend { id: batteryBackend }
    BatteryService { id: battery; backend: batteryBackend }
    MockPowerProfileBackend { id: profileBackend }
    PowerProfileService { id: powerProfiles; backend: profileBackend }
    MockSessionBackend { id: sessionBackend }
    SessionService { id: session; backend: sessionBackend }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notifications; backend: notificationBackend; screens: preview.coordinator.screens; monitorService: preview.backend }
    NotificationFocus { id: notificationFocus; service: notifications; panels: preview.coordinator; barFocus: preview.barController }
    QtObject {
        id: messages
        property bool blocked: false
        property var calls: []
        function open(monitor: string): bool { calls = calls.concat([monitor]); return true; }
    }
    ActionController {
        id: actions
        coordinator: preview.coordinator; launcher: launcher; hyprland: preview.workspaceService; windowActions: windowActions
        barFocus: preview.barController; notificationFocus: notificationFocus; notifications: notifications
        audio: audio; brightness: brightness; sessionService: session
        powerProfiles: powerProfiles
        messages: messages
    }
    QtObject {
        id: loader
        property bool activeAsync: false
        readonly property bool active: itemLoader.status === Loader.Ready
        readonly property var item: active ? itemLoader.item : null
        readonly property Loader itemLoader: Loader { active: loader.activeAsync; asynchronous: true; sourceComponent: preview.panelComponent }
    }
    PanelPreviewScene { id: preview; anchors.fill: parent; panelLoader: loader; settings: settings; launcher: launcher; audio: audio; notifications: notifications; sessionService: session; powerProfiles: powerProfiles; network: network; bluetooth: bluetooth; battery: battery }
    SignalSpy { id: panelPresented; target: preview.coordinator; signalName: "presented" }
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
            messages.calls = [];
            sessionBackend.reset(); session.lastError = "";
            networkBackend.reset(); bluetoothBackend.reset();
            profileBackend.available = true; profileBackend.profile = "balanced";
            profileBackend.profiles = ["power-saver", "balanced", "performance"];
            profileBackend.pendingProfile = ""; profileBackend.lastError = "";
            profileBackend.calls = 0; profileBackend.autoComplete = true;
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
            compare(backend.applied.find(row => row.action === "messages").shortcut, "SUPER + CONTROL + SHIFT + Return");
            compare(backend.applied.find(row => row.action === "quickSettings").shortcut, "SUPER + Q");
            compare(Actions.shortcut("Super + ;"), "SUPER + semicolon");
            compare(Actions.find("commands").shortcut, "SUPER + semicolon");
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
        function test_command_suggestions_data() {
            return [{tag: "colon", chip: false}, {tag: "command-chip", chip: true}, {tag: "colon-space", chip: false, space: true}];
        }
        function test_command_suggestions(data) {
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => control("launcherSearch") && control("launcherSearch").activeFocus);
            if (data.chip) launcher.startMode("commands");
            else type(":");
            if (data.space) keyClick(Qt.Key_Space);
            if (data.chip || data.space) {
                compare(control("launcherChip").text, "Komenda");
                compare(control("launcherSearch").text, "");
                verify(control("launcherSearch").activeFocus);
            }
            compare(launcher.results.length, keyboard.persisted.filter(row => row.command).length - 1);
            compare(launcher.results.filter(entry => entry.title === "Wyłącz komputer").length, 1);
            type("s");
            compare(launcher.results.map(entry => entry.action), ["screenshot", "settings", "shutdown", "sleep"]);
            type("l");
            compare(launcher.results.length, 1);
            compare(launcher.results[0].action, "sleep");
            const list = control("launcherResults");
            tryVerify(() => list.itemAtIndex(0) !== null && list.itemAtIndex(0).modelData.action === "sleep");
            const row = list.itemAtIndex(0);
            compare(findChild(row, "launcherRowTitle").text, "Uśpij");
            verify(findChild(row, "launcherRowSubtitle").visible);
            compare(findChild(row, "launcherRowSubtitle").text, "Sesja");
            compare(findChild(row, "launcherApplicationIcon").symbol, "power_settings_new");
            verify(!launcher.searching);
            compare(sessionBackend.calls, []);
            sessionBackend.automatic = false;
            keyClick(Qt.Key_Return);
            compare(sessionBackend.calls, ["lock-requested"]);
            sessionBackend.confirmLock();
            compare(sessionBackend.calls, ["lock-requested", "lock-confirmed", "suspend"]);
        }
        function test_command_suggestion_selection_data() {
            return [{tag: "keyboard", mouse: false}, {tag: "mouse", mouse: true}];
        }
        function test_command_suggestion_selection(data) {
            saveAlias("floating", ":sleep-more");
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => control("launcherSearch") && control("launcherSearch").activeFocus);
            type(":sleep");
            compare(launcher.results.map(entry => entry.action), ["sleep", "floating"]);
            preview.backend.activeWindow = preview.backend.secondWindow;
            const list = control("launcherResults");
            tryVerify(() => list.itemAtIndex(1) !== null);
            if (data.mouse) mouseClick(list.itemAtIndex(1));
            else { keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); }
            compare(windowActions.calls, [{action: "floating", address: "0x123", monitor: "TEST-1"}]);
            compare(sessionBackend.calls, []);
        }
        function test_command_suggestions_follow_saved_aliases_and_query() {
            saveAlias("floating", ":float");
            saveAlias("audio", ":audio");
            saveAlias("clipboard", ":clip");
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            for (const entry of [{query: ":f", action: "floating"}, {query: ":a", action: "audio"}, {query: ":c", action: "clipboard"}]) {
                launcher.edit(entry.query);
                verify(launcher.commandInput);
                compare(launcher.results[0].action, entry.action);
            }
            launcher.edit(" :SL ");
            compare(launcher.results[0].action, "sleep");
            const previous = launcher.results[0];
            launcher.edit(":hi");
            verify(!launcher.activate(previous));
            launcher.edit(":sl");
            saveAlias("sleep", ":nap");
            compare(launcher.results.length, 0);
            verify(!launcher.activate(previous));
            launcher.edit(":na");
            compare(launcher.results[0].action, "sleep");
            saveAlias("sleep", "");
            compare(launcher.results.length, 0);
            keyClick(Qt.Key_Return);
            compare(sessionBackend.calls, []);
            compare(windowActions.calls, []);
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
        function test_default_settings_command() {
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            launcher.edit(":settings");
            compare(launcher.results[0].action, "settings");
            verify(launcher.activate(launcher.results[0]));
            tryCompare(preview.coordinator, "activeId", "settings");
        }
        function topbarCommands() {
            return [
                {action: "network", command: ":wifi", title: "Wi-Fi", category: "Sieć", icon: "network_wifi", focus: "wifiRadio"},
                {action: "bluetooth", command: ":bluetooth", title: "Bluetooth", category: "Bluetooth", icon: "bluetooth", focus: "bluetoothRadio"},
                {action: "audio", command: ":volume", title: "Głośność", category: "Dźwięk", icon: "volume_up", focus: "audioVolume"},
                {action: "battery", command: ":battery", title: "Bateria", category: "Bateria", icon: "battery_android_full", focus: "batteryProfile-balanced"},
                {action: "notifications", command: ":notifications", title: "Powiadomienia", category: "Powiadomienia", icon: "notifications", focus: "notificationDnd"},
                {action: "quickSettings", command: ":quickmenu", title: "Quick Menu", category: "Ustawienia", icon: "tune", focus: "audioVolume"}
            ];
        }
        function test_topbar_commands_open_panels_data() {
            const cases = [];
            for (const entry of topbarCommands())
                for (const mode of ["colon", "chip", "colon-space"])
                    cases.push(Object.assign({}, entry, {tag: entry.action + "-" + mode, mode: mode}));
            return cases;
        }
        function test_topbar_commands_open_panels(data) {
            const screen = data.mode === "chip" ? preview.secondScreen : preview.firstScreen;
            const monitor = data.mode === "chip" ? "TEST-2" : "TEST-1";
            preview.backend.focusedMonitorName = monitor;
            verify(preview.coordinator.open("launcher", screen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => control("launcherSearch") && control("launcherSearch").activeFocus);
            panelPresented.clear();
            if (data.mode === "chip") launcher.startMode("commands");
            type((data.mode === "chip" ? "" : data.mode === "colon-space" ? ": " : ":") + data.command.slice(1, -1));
            compare(launcher.results.length, 1);
            compare(launcher.results[0].action, data.action);
            type(data.command.slice(-1));
            compare(launcher.results[0].id, data.command);
            const list = control("launcherResults");
            tryVerify(() => list.itemAtIndex(0) !== null && list.itemAtIndex(0).modelData.action === data.action);
            const row = list.itemAtIndex(0);
            compare(findChild(row, "launcherRowTitle").text, data.title);
            compare(findChild(row, "launcherRowSubtitle").text, data.category);
            compare(findChild(row, "launcherApplicationIcon").symbol, data.icon);
            compare(panelPresented.count, 0);
            compare(preview.coordinator.activeId, "launcher");
            keyClick(Qt.Key_Return);
            tryCompare(preview.coordinator, "activeId", data.action);
            compare(preview.coordinator.screenName, monitor);
            tryVerify(() => control(data.focus) && control(data.focus).activeFocus);
            compare(preview.coordinator.session.focusReason, Qt.TabFocusReason);
            verify(!launcher.active);
            compare(panelPresented.count, 1);
            compare(networkBackend.radioCalls, 0);
            compare(bluetoothBackend.calls, []);
            compare(profileBackend.calls, 0);
            compare(sessionBackend.calls, []);
            compare(windowActions.calls, []);
            compare(launcherBackend.activations.length, 0);
        }
        function test_messages_command_search_and_open_data() {
            const cases = [];
            for (const query of ["messages", "wiadomosci", "Wiadomości"])
                for (const mode of ["colon", "chip", "colon-space"])
                    cases.push({tag: query + "-" + mode, query: query, mode: mode});
            return cases;
        }
        function test_messages_command_search_and_open(data) {
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => control("launcherSearch") && control("launcherSearch").activeFocus);
            if (data.mode === "chip") launcher.startMode("commands");
            else type(data.mode === "colon-space" ? ": " : ":");
            verify(launcher.results.some(entry => entry.action === "messages"));
            if (data.query === "Wiadomości") {
                launcher.edit(launcher.text + data.query);
            } else type(data.query);
            compare(launcher.commandText, ":" + data.query);
            compare(launcher.results.length, 1);
            compare(launcher.results[0].action, "messages");
            const list = control("launcherResults");
            tryVerify(() => list.itemAtIndex(0) !== null && list.itemAtIndex(0).modelData.action === "messages");
            compare(findChild(list.itemAtIndex(0), "launcherRowTitle").text, "Wiadomości");
            compare(messages.calls, []);
            keyClick(Qt.Key_Return);
            tryCompare(messages, "calls", ["TEST-1"]);
            tryCompare(preview.coordinator, "activeId", "");
        }
        function previousPanelBindings() {
            return Actions.defaults().filter(row => ["network", "bluetooth"].indexOf(row.action) < 0)
                .map(row => ["quickSettings", "audio", "battery", "notifications"].indexOf(row.action) >= 0
                    ? Object.assign({}, row, {command: ""}) : row);
        }
        function test_migrate_topbar_commands_data() {
            return [
                {tag: "previous", omitted: []},
                {tag: "pre-messages", omitted: ["messages"]},
                {tag: "pre-profiles", omitted: ["messages", "powersaver", "balanced", "performance"]},
                {tag: "oldest", omitted: ["messages", "powersaver", "balanced", "performance", "shutdown", "poweroff", "sleep", "hibernate", "reboot", "screenshot"]}
            ];
        }
        function test_migrate_topbar_commands(data) {
            const rows = previousPanelBindings().filter(row => data.omitted.indexOf(row.action) < 0);
            file.external(JSON.stringify({schemaVersion: 1, bindings: rows}));
            compare(keyboard.readProblem, "");
            compare(file.writes, 0);
            for (const entry of topbarCommands())
                compare(keyboard.command(entry.command).action, entry.action);
            compare(keyboard.command(":messages").action, "messages");
            for (const row of rows)
                compare(keyboard.persisted.find(value => value.action === row.action).shortcut, row.shortcut);
            compare(keyboard.persisted.find(row => row.action === "network").shortcut, "");
            compare(keyboard.persisted.find(row => row.action === "bluetooth").shortcut, "");
            keyboard.beginEdit();
            verify(keyboard.save()); tryCompare(keyboard, "saving", false);
            compare(keyboard.problem, ""); compare(file.writes, 1);
            const saved = Actions.parse(file.snapshot.text);
            verify(!saved.error); compare(saved.value, keyboard.persisted);
        }
        function test_topbar_migration_preserves_aliases_and_conflicts() {
            const rows = previousPanelBindings();
            const aliases = {quickSettings: ":menu", audio: ":sound", settings: ":WIFI", lock: ":BLUETOOTH",
                volumeDown: ":BATTERY", dnd: ":NOTIFICATIONS"};
            for (const row of rows) if (aliases[row.action]) row.command = aliases[row.action];
            file.external(JSON.stringify({schemaVersion: 1, bindings: rows}));
            compare(keyboard.readProblem, ""); compare(file.writes, 0);
            for (const action of Object.keys(aliases))
                compare(keyboard.command(aliases[action].toLowerCase()).action, action);
            for (const action of ["network", "bluetooth", "battery", "notifications"])
                compare(keyboard.persisted.find(row => row.action === action).command, "");
            compare(keyboard.command(":quickmenu"), null); compare(keyboard.command(":volume"), null);
        }
        function test_topbar_commands_stay_removed_after_save() {
            keyboard.beginEdit();
            for (const entry of topbarCommands()) keyboard.setBinding(entry.action, "command", "");
            verify(keyboard.save()); tryCompare(keyboard, "saving", false);
            compare(keyboard.problem, "");
            const saved = Actions.parse(file.snapshot.text);
            verify(!saved.error);
            for (const entry of topbarCommands()) {
                compare(keyboard.command(entry.command), null);
                compare(saved.value.find(row => row.action === entry.action).command, "");
            }
        }
        function test_command_names_alias_priority_and_disabled_action() {
            compare(keyboard.commandMatches(":GLOSNOSC").map(entry => entry.action), ["audio"]);
            compare(keyboard.commandMatches(":glosnosc").map(entry => entry.action), ["audio"]);
            compare(keyboard.commandMatches(":Wi-Fi").map(entry => entry.action), ["network"]);
            compare(keyboard.commandMatches(":menu").map(entry => entry.action), ["quickSettings"]);
            saveAlias("messages", ":chat");
            compare(keyboard.commandMatches(":wiadomosci").map(entry => entry.action), ["messages"]);
            compare(keyboard.commandMatches(":chat").map(entry => entry.action), ["messages"]);
            compare(keyboard.commandMatches(":messages"), []);
            saveAlias("floating", ":wiadomosci");
            compare(keyboard.commandMatches(":wiadomosci").map(entry => entry.action), ["floating", "messages"]);
            saveAlias("messages", "");
            compare(keyboard.commandMatches(":Wiadomości").map(entry => entry.action), []);
            compare(keyboard.commandMatches(":wiadomosci").map(entry => entry.action), ["floating"]);
        }
        function test_topbar_migration_rejects_incomplete_catalogs() {
            const previous = previousPanelBindings();
            const partial = previous.concat([Actions.defaults().find(row => row.action === "network")]);
            for (const rows of [previous.slice(1), partial, Actions.defaults().filter(row => row.action !== "network")])
                verify(!!Actions.parse(JSON.stringify({schemaVersion: 1, bindings: rows})).error);
        }
        function test_session_commands_data() {
            return [
                {tag: "shutdown", action: "shutdown", requested: "poweroff", confirm: true},
                {tag: "poweroff", action: "poweroff", requested: "poweroff", confirm: true},
                {tag: "reboot", action: "reboot", requested: "reboot", confirm: true},
                {tag: "sleep", action: "sleep", requested: "suspend", confirm: false},
                {tag: "hibernate", action: "hibernate", requested: "hibernate", confirm: false},
                {tag: "lock", action: "lock", requested: "lock", confirm: false}
            ];
        }
        function test_session_commands(data) {
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            launcher.startMode("commands");
            launcher.edit(data.action.slice(0, -1)); compare(launcher.results.length, 1);
            compare(launcher.results[0].action, data.action);
            launcher.edit(data.action); compare(launcher.results.length, 1);
            sessionBackend.automatic = false;
            verify(launcher.activate(launcher.results[0]));
            if (data.confirm) {
                tryCompare(preview.coordinator, "activeId", "power");
                tryVerify(() => control("powerCancel") && control("powerCancel").activeFocus);
                compare(sessionBackend.calls, []);
                compare(loader.item.page.confirmation, data.requested);
                keyClick(Qt.Key_L); keyClick(Qt.Key_Return); keyClick(Qt.Key_Return);
                compare(sessionBackend.calls, [data.requested]);
                sessionBackend.settle(true, "");
            } else {
                compare(sessionBackend.calls, ["lock-requested"]);
                compare(session.phase, "locking");
                sessionBackend.confirmLock();
                compare(sessionBackend.calls, data.requested === "lock" ? ["lock-requested", "lock-confirmed"]
                    : ["lock-requested", "lock-confirmed", data.requested]);
            }
            verify(!session.busy);
            compare(windowActions.calls, []);
            compare(launcherBackend.activations.length, 0);
        }
        function test_power_command_cancel_and_unavailable_session() {
            verify(actions.invoke("shutdown", null, "TEST-1"));
            tryCompare(preview.coordinator, "activeId", "power");
            tryVerify(() => control("powerCancel") && control("powerCancel").activeFocus);
            keyClick(Qt.Key_Return);
            compare(sessionBackend.calls, []);
            compare(loader.item.page.confirmation, "");
            sessionBackend.ready = false; sessionBackend.errorText = "Sesja niedostępna";
            for (const action of ["shutdown", "poweroff", "reboot", "sleep", "hibernate", "lock"]) {
                verify(!actions.invoke(action, null, "TEST-1"));
                compare(actions.lastError, "Sesja niedostępna");
            }
            compare(sessionBackend.calls, []);
        }
        function test_shutdown_aliases_share_one_result() {
            for (const query of [":", ":sh", ":shutdown", ":po", ":poweroff"])
                compare(keyboard.commandMatches(query).filter(entry => entry.title === "Wyłącz komputer").length, 1);
            saveAlias("shutdown", ":stop");
            saveAlias("poweroff", ":stop-now");
            compare(keyboard.commandMatches(":stop").length, 1);
            compare(keyboard.command(":stop").action, "shutdown");
            compare(keyboard.command(":stop-now").action, "poweroff");
        }
        function test_power_profile_commands_data() {
            const cases = [];
            for (const command of ["powersaver", "balanced", "performance"])
                for (const mode of ["colon", "chip", "colon-space"])
                    cases.push({tag: command + "-" + mode, command: command,
                        profile: command === "powersaver" ? "power-saver" : command, mode: mode});
            return cases;
        }
        function test_power_profile_commands(data) {
            profileBackend.profile = data.profile === "balanced" ? "power-saver" : "balanced";
            const previous = profileBackend.profile;
            profileBackend.autoComplete = false;
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => control("launcherSearch") && control("launcherSearch").activeFocus);
            if (data.mode === "chip") launcher.startMode("commands");
            type((data.mode === "chip" ? "" : data.mode === "colon-space" ? ": " : ":") + data.command.slice(0, -1));
            compare(launcher.results.length, 1);
            compare(launcher.results[0].action, data.command);
            const list = control("launcherResults");
            tryVerify(() => list.itemAtIndex(0) !== null && list.itemAtIndex(0).modelData.action === data.command);
            const row = list.itemAtIndex(0);
            verify(findChild(row, "launcherRowSubtitle").visible);
            compare(findChild(row, "launcherRowSubtitle").text, "Bateria");
            compare(findChild(row, "launcherApplicationIcon").symbol, "battery_android_full");
            compare(profileBackend.calls, 0);
            keyClick(Qt.Key_Return);
            compare(profileBackend.calls, 1);
            compare(powerProfiles.pendingProfile, data.profile);
            compare(powerProfiles.profile, previous);
            profileBackend.complete(true);
            compare(powerProfiles.profile, data.profile);
            tryCompare(preview.coordinator, "activeId", "");
            verify(preview.coordinator.open("battery", preview.firstScreen, null));
            tryVerify(() => control("batteryProfile-" + data.profile) !== null);
            verify(control("batteryProfile-" + data.profile).checked);
            compare(sessionBackend.calls, []);
        }
        function test_command_category_follows_action_after_alias_edit_data() {
            return [
                {tag: "profile", action: "balanced", category: "Bateria", icon: "battery_android_full"},
                {tag: "audio", action: "volumeDown", category: "Dźwięk", icon: "volume_up"},
                {tag: "settings", action: "settings", category: "Ustawienia", icon: "settings"},
                {tag: "quick-menu", action: "quickSettings", category: "Ustawienia", icon: "tune"},
                {tag: "wifi", action: "network", category: "Sieć", icon: "network_wifi"},
                {tag: "bluetooth", action: "bluetooth", category: "Bluetooth", icon: "bluetooth"},
                {tag: "messages", action: "messages", category: "Wiadomości", icon: "chat_bubble"},
                {tag: "clipboard", action: "clipboard", category: "Schowek", icon: "content_paste"},
                {tag: "notifications", action: "dnd", category: "Powiadomienia", icon: "notifications"},
                {tag: "screen", action: "screenshot", category: "Ekran", icon: "desktop_windows"},
                {tag: "window", action: "floating", category: "Okna", icon: "desktop_windows"},
                {tag: "workspace", action: "workspace3", category: "Workspace", icon: "desktop_windows"}
            ];
        }
        function test_command_category_follows_action_after_alias_edit(data) {
            saveAlias(data.action, ":custom");
            verify(preview.coordinator.open("launcher", preview.firstScreen, null));
            tryCompare(loader, "active", true);
            tryVerify(() => control("launcherSearch") && control("launcherSearch").activeFocus);
            type(": custom");
            compare(launcher.chipMode, "command"); compare(launcher.results.length, 1);
            const list = control("launcherResults");
            tryVerify(() => list.itemAtIndex(0) !== null && list.itemAtIndex(0).modelData.action === data.action);
            tryVerify(() => control("launcherResultsFade").current && control("launcherResultsFade").opacity === 1);
            const row = list.itemAtIndex(0), subtitle = findChild(row, "launcherRowSubtitle");
            verify(subtitle.visible); compare(subtitle.text, data.category);
            compare(findChild(row, "launcherApplicationIcon").symbol, data.icon);
            verify(subtitle.width <= row.availableWidth * 0.45);
            verify(row.Accessible.name.endsWith(", " + data.category));
            verify(control("launcherSearch").activeFocus);
            compare(profileBackend.calls, 0); compare(sessionBackend.calls, []);
            compare(windowActions.calls, []); compare(launcherBackend.activations.length, 0);
        }
        function test_power_profile_rejections_and_already_active() {
            verify(actions.invoke("balanced", null, "TEST-1"));
            compare(profileBackend.calls, 0);
            profileBackend.available = false;
            verify(!actions.invoke("powersaver", null, "TEST-1"));
            verify(actions.lastError.length > 0);
            profileBackend.available = true;
            profileBackend.profiles = ["power-saver", "balanced"];
            verify(!actions.invoke("performance", null, "TEST-1"));
            verify(actions.lastError.length > 0);
            profileBackend.autoComplete = false;
            verify(actions.invoke("powersaver", null, "TEST-1"));
            verify(!actions.invoke("balanced", null, "TEST-1"));
            compare(profileBackend.calls, 1);
            profileBackend.complete(false);
            compare(powerProfiles.profile, "balanced");
            verify(powerProfiles.lastError.length > 0);
            compare(windowActions.calls, []);
        }
        function test_migrate_power_profile_commands() {
            const profiles = ["powersaver", "balanced", "performance"];
            const previous = Actions.defaults().filter(row => profiles.indexOf(row.action) < 0);
            previous.find(row => row.action === "audio").command = ":BALANCED";
            previous.find(row => row.action === "sleep").command = ":nap";
            file.external(JSON.stringify({schemaVersion: 1, bindings: previous}));
            compare(keyboard.readProblem, ""); compare(file.writes, 0);
            compare(keyboard.command(":powersaver").action, "powersaver");
            compare(keyboard.command(":performance").action, "performance");
            compare(keyboard.command(":balanced").action, "audio");
            compare(keyboard.command(":nap").action, "sleep");
            compare(keyboard.persisted.find(row => row.action === "balanced").command, "");
            verify(!!Actions.parse(JSON.stringify({schemaVersion: 1, bindings: previous.slice(1)})).error);
            const partial = previous.concat([Actions.defaults().find(row => row.action === "powersaver")]);
            verify(!!Actions.parse(JSON.stringify({schemaVersion: 1, bindings: partial})).error);
            saveAlias("powersaver", "");
            const saved = Actions.parse(file.snapshot.text);
            verify(!saved.error);
            compare(saved.value.find(row => row.action === "powersaver").command, "");
        }
        function legacyBindings(screenshot) {
            const added = ["shutdown", "poweroff", "sleep", "hibernate", "reboot", "powersaver", "balanced", "performance"];
            return Actions.defaults().filter(row => added.indexOf(row.action) < 0 && (screenshot || row.action !== "screenshot"))
                .map(row => Object.assign({}, row, row.action === "commands" ? {shortcut: "SUPER + SHIFT + semicolon"}
                    : row.action === "settings" || row.action === "lock" ? {command: ""} : {}));
        }
        function test_migrate_session_commands_and_shortcut() {
            for (const screenshot of [false, true]) {
                const rows = legacyBindings(screenshot);
                rows[0].command = ":start";
                file.external(JSON.stringify({schemaVersion: 1, bindings: rows}));
                compare(keyboard.readProblem, ""); compare(file.writes, 0);
                compare(backend.applied.find(row => row.action === "commands").shortcut, "SUPER + semicolon");
                for (const action of ["settings", "lock", "shutdown", "poweroff", "sleep", "hibernate", "reboot", "screenshot", "powersaver", "balanced", "performance"])
                    compare(keyboard.command(":" + action).action, action);
                compare(keyboard.command(":start").action, "launcher");
                verify(!!Actions.parse(JSON.stringify({schemaVersion: 1, bindings: rows.slice(1)})).error);
            }
        }
        function test_migration_preserves_custom_bindings_and_conflicts() {
            const rows = legacyBindings(true);
            rows.find(row => row.action === "commands").shortcut = "SUPER + ALT + C";
            rows.find(row => row.action === "settings").command = ":prefs";
            rows.find(row => row.action === "audio").command = ":SHUTDOWN";
            rows.find(row => row.action === "brightnessUp").command = ":lock";
            const parsed = Actions.parse(JSON.stringify({schemaVersion: 1, bindings: rows}));
            verify(!parsed.error);
            compare(parsed.value.find(row => row.action === "commands").shortcut, "SUPER + ALT + C");
            compare(parsed.value.find(row => row.action === "settings").command, ":prefs");
            compare(parsed.value.find(row => row.action === "shutdown").command, "");
            compare(parsed.value.find(row => row.action === "lock").command, "");
            rows.find(row => row.action === "commands").shortcut = "SUPER + SHIFT + semicolon";
            rows.find(row => row.action === "audio").shortcut = "SUPER + ;";
            const collision = Actions.parse(JSON.stringify({schemaVersion: 1, bindings: rows}));
            verify(!collision.error);
            compare(collision.value.find(row => row.action === "commands").shortcut, "SUPER + SHIFT + semicolon");
            const current = Actions.defaults();
            current.find(row => row.action === "commands").shortcut = "SUPER + SHIFT + semicolon";
            current.find(row => row.action === "lock").command = "";
            compare(Actions.parse(Actions.serialize(current)).value, current);
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
