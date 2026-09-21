.pragma library

// Closed catalog. A command names an action; it is never a shell expression.
var catalog = [
    {id: "launcher", title: "Launcher", group: "Shell", shortcut: "SUPER + SPACE"},
    {id: "clipboard", title: "Schowek", group: "Shell", shortcut: "SUPER + V"},
    {id: "commands", title: "Launcher komend", group: "Shell", shortcut: "SUPER + semicolon"},
    {id: "settings", title: "Ustawienia", group: "Shell", command: ":settings"},
    {id: "quickSettings", title: "Szybkie ustawienia", group: "Shell", shortcut: "SUPER + SHIFT + Q"},
    {id: "audio", title: "Panel dźwięku", group: "Shell"},
    {id: "battery", title: "Panel baterii", group: "Shell"},
    {id: "bar", title: "Nawigacja paskiem", group: "Shell", shortcut: "SUPER + B"},
    {id: "notifications", title: "Powiadomienia", group: "Shell", shortcut: "SUPER + SHIFT + N"},
    {id: "dnd", title: "Nie przeszkadzać", group: "Shell"},
    {id: "screenshot", title: "Zrzut ekranu", group: "Shell", shortcut: "Print", command: ":screenshot"},
    {id: "volumeUp", title: "Głośniej", group: "Dźwięk"},
    {id: "volumeDown", title: "Ciszej", group: "Dźwięk"},
    {id: "mute", title: "Wyciszenie głośnika", group: "Dźwięk"},
    {id: "micMute", title: "Wyciszenie mikrofonu", group: "Dźwięk"},
    {id: "brightnessUp", title: "Jaśniej", group: "Ekran"},
    {id: "brightnessDown", title: "Ciemniej", group: "Ekran"},
    {id: "powersaver", title: "Tryb oszczędny", group: "Zasilanie", command: ":powersaver"},
    {id: "balanced", title: "Tryb zrównoważony", group: "Zasilanie", command: ":balanced"},
    {id: "performance", title: "Tryb wydajności", group: "Zasilanie", command: ":performance"},
    {id: "power", title: "Menu zasilania", group: "Sesja", shortcut: "SUPER + SHIFT + P"},
    {id: "lock", title: "Zablokuj ekran", group: "Sesja", command: ":lock"},
    {id: "shutdown", title: "Wyłącz komputer", group: "Sesja", command: ":shutdown", aliasOf: "poweroff"},
    {id: "poweroff", title: "Wyłącz komputer", group: "Sesja", command: ":poweroff"},
    {id: "sleep", title: "Uśpij", group: "Sesja", command: ":sleep"},
    {id: "hibernate", title: "Hibernuj", group: "Sesja", command: ":hibernate"},
    {id: "reboot", title: "Uruchom ponownie", group: "Sesja", command: ":reboot"},
    {id: "closeWindow", title: "Zamknij okno", group: "Hyprland"},
    {id: "floating", title: "Przełącz pływające okno", group: "Hyprland"},
    {id: "fullscreen", title: "Przełącz pełny ekran", group: "Hyprland"},
    {id: "focusLeft", title: "Fokus w lewo", group: "Hyprland"},
    {id: "focusDown", title: "Fokus w dół", group: "Hyprland"},
    {id: "focusUp", title: "Fokus w górę", group: "Hyprland"},
    {id: "focusRight", title: "Fokus w prawo", group: "Hyprland"},
    {id: "moveLeft", title: "Przenieś okno w lewo", group: "Hyprland"},
    {id: "moveDown", title: "Przenieś okno w dół", group: "Hyprland"},
    {id: "moveUp", title: "Przenieś okno w górę", group: "Hyprland"},
    {id: "moveRight", title: "Przenieś okno w prawo", group: "Hyprland"}
];
for (var workspace = 1; workspace <= 10; ++workspace) {
    catalog.push({id: "workspace" + workspace, title: "Workspace " + workspace, group: "Hyprland"});
    catalog.push({id: "moveWorkspace" + workspace, title: "Przenieś okno do workspace " + workspace, group: "Hyprland"});
}

function find(id) { return catalog.find(action => action.id === id) || null; }
function defaults() { return catalog.map(action => ({action: action.id, shortcut: action.shortcut || "", command: action.command || ""})); }
function copy(value) { return JSON.parse(JSON.stringify(value)); }
function shortcut(value) {
    if (typeof value !== "string") return null;
    if (!value.trim()) return "";
    const parts = value.split("+").map(part => part.trim());
    let key = parts.pop();
    const mods = parts.map(part => part.toUpperCase().replace(/^CTRL$/, "CONTROL").replace(/^META$/, "SUPER"));
    if (key === ":") { key = "semicolon"; if (mods.indexOf("SHIFT") < 0) mods.push("SHIFT"); }
    else if (key === ";") key = "semicolon";
    if (!key || !/^[A-Za-z0-9_]+$/.test(key) || mods.some(mod => ["SUPER", "CONTROL", "ALT", "SHIFT"].indexOf(mod) < 0)
            || new Set(mods).size !== mods.length) return null;
    const order = ["SUPER", "CONTROL", "ALT", "SHIFT"].filter(mod => mods.indexOf(mod) >= 0);
    // Hyprland uses the unshifted symbol, with Shift represented separately.
    const names = {space: "SPACE", tab: "Tab", return: "Return", enter: "Return", escape: "Escape", esc: "Escape",
        left: "Left", right: "Right", up: "Up", down: "Down", delete: "Delete", backspace: "BackSpace",
        home: "Home", end: "End", pageup: "Prior", pagedown: "Next", print: "Print"};
    const normalized = names[key.toLowerCase()] || (key.length === 1 ? key.toUpperCase() : key);
    if (!order.length && !/^(?:F(?:[1-9]|[12][0-9]|3[0-5])|XF86[A-Za-z0-9]+|Print)$/.test(normalized)) return null;
    return order.concat([normalized]).join(" + ");
}
function problem(rows) {
    if (!Array.isArray(rows) || rows.length !== catalog.length) return "Niepoprawna lista działań.";
    const ids = new Set(), keys = new Set(), commands = new Set();
    for (const row of rows) {
        if (!row || !find(row.action) || ids.has(row.action) || Object.keys(row).some(key => ["action", "shortcut", "command"].indexOf(key) < 0))
            return "Nieznane lub powtórzone działanie.";
        ids.add(row.action);
        const key = shortcut(row.shortcut);
        if (key === null) return "Niepoprawny skrót: " + find(row.action).title;
        if (key && keys.has(key.toLowerCase())) return "Powtórzony skrót: " + key;
        if (key) keys.add(key.toLowerCase());
        if (typeof row.command !== "string" || (row.command && !/^:[a-zA-Z][a-zA-Z0-9_-]{0,39}$/.test(row.command)))
            return "Niepoprawna komenda: " + find(row.action).title;
        const command = row.command.toLowerCase();
        if (/^:(?:[afc]|(?:mw|w)[0-9]?)$/.test(command)) return "Zarezerwowana komenda: " + command;
        if (command && commands.has(command)) return "Powtórzona komenda: " + command;
        if (command) commands.add(command);
    }
    return "";
}
function normalize(rows) { return rows.map(row => ({action: row.action, shortcut: shortcut(row.shortcut), command: row.command.toLowerCase()})); }
function completeCatalog(rows, actions) {
    return Array.isArray(rows) && rows.length === actions.length
        && actions.every(action => rows.filter(row => row && row.action === action.id).length === 1);
}
function parse(text) {
    let value;
    try { value = JSON.parse(text); } catch (_) { return {error: "Niepoprawny JSON ustawień klawiatury."}; }
    if (!value || value.schemaVersion !== 1 || Object.keys(value).some(key => ["schemaVersion", "bindings"].indexOf(key) < 0))
        return {error: "Nieobsługiwana wersja lub opcje ustawień klawiatury."};
    // Upgrade complete catalogs from before the session commands, with or
    // without screenshot. Never fill arbitrary holes in a damaged catalog.
    const profiles = ["powersaver", "balanced", "performance"];
    const previousCatalog = catalog.filter(action => profiles.indexOf(action.id) < 0);
    const sessionCatalog = Array.isArray(value.bindings) && value.bindings.some(row => row && profiles.indexOf(row.action) >= 0)
        ? catalog : previousCatalog;
    const added = ["shutdown", "poweroff", "sleep", "hibernate", "reboot"];
    if (Array.isArray(value.bindings) && !value.bindings.some(row => row && added.indexOf(row.action) >= 0)) {
        const legacy = sessionCatalog.filter(action => added.indexOf(action.id) < 0
            && (action.id !== "screenshot" || value.bindings.some(row => row && row.action === "screenshot")));
        if (completeCatalog(value.bindings, legacy)) {
            const usedCommands = value.bindings.map(row => typeof row.command === "string" ? row.command.toLowerCase() : "");
            const usedShortcuts = value.bindings.filter(row => row.action !== "commands").map(row => shortcut(row.shortcut));
            value.bindings = value.bindings.map(row => {
                if (row.action === "commands" && shortcut(row.shortcut) === "SUPER + SHIFT + semicolon"
                        && usedShortcuts.indexOf("SUPER + semicolon") < 0)
                    return Object.assign({}, row, {shortcut: find("commands").shortcut});
                if ((row.action === "settings" || row.action === "lock") && row.command === ""
                        && usedCommands.indexOf(find(row.action).command) < 0)
                    return Object.assign({}, row, {command: find(row.action).command});
                return row;
            }).concat(defaults().filter(row => added.indexOf(row.action) >= 0).map(row =>
                usedCommands.indexOf(row.command) < 0 ? row : Object.assign({}, row, {command: ""})));
        }
    }
    // The oldest complete catalog also predates screenshot.
    if (completeCatalog(value.bindings, sessionCatalog.filter(action => action.id !== "screenshot"))) {
        const action = find("screenshot");
        value.bindings = value.bindings.concat([{action: action.id, shortcut: action.shortcut, command: action.command}]);
    }
    // Add profile commands only to a complete previous catalog. Existing aliases win.
    if (completeCatalog(value.bindings, previousCatalog)) {
        const usedCommands = value.bindings.map(row => typeof row.command === "string" ? row.command.toLowerCase() : "");
        value.bindings = value.bindings.concat(defaults().filter(row => profiles.indexOf(row.action) >= 0).map(row =>
            usedCommands.indexOf(row.command) < 0 ? row : Object.assign({}, row, {command: ""})));
    }
    const error = problem(value.bindings);
    return error ? {error: error} : {value: normalize(value.bindings)};
}
function serialize(rows) { return JSON.stringify({schemaVersion: 1, bindings: normalize(rows)}, null, 2) + "\n"; }
