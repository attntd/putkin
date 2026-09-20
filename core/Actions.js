.pragma library

// Closed catalog. A command names an action; it is never a shell expression.
var catalog = [
    {id: "launcher", title: "Launcher", group: "Shell", shortcut: "SUPER + SPACE"},
    {id: "clipboard", title: "Schowek", group: "Shell", shortcut: "SUPER + V"},
    {id: "commands", title: "Launcher komend", group: "Shell", shortcut: "SUPER + SHIFT + semicolon"},
    {id: "settings", title: "Ustawienia", group: "Shell"},
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
    {id: "power", title: "Menu zasilania", group: "Sesja", shortcut: "SUPER + SHIFT + P"},
    {id: "lock", title: "Zablokuj ekran", group: "Sesja"},
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
function parse(text) {
    let value;
    try { value = JSON.parse(text); } catch (_) { return {error: "Niepoprawny JSON ustawień klawiatury."}; }
    if (!value || value.schemaVersion !== 1 || Object.keys(value).some(key => ["schemaVersion", "bindings"].indexOf(key) < 0))
        return {error: "Nieobsługiwana wersja lub opcje ustawień klawiatury."};
    // Upgrade exactly the previous complete catalog, preserving user edits.
    // A truncated or unknown catalog still fails normal validation.
    if (Array.isArray(value.bindings) && value.bindings.length === catalog.length - 1
            && !value.bindings.some(row => row && row.action === "screenshot")) {
        const action = find("screenshot");
        value.bindings = value.bindings.concat([{action: action.id, shortcut: action.shortcut, command: action.command}]);
    }
    const error = problem(value.bindings);
    return error ? {error: error} : {value: normalize(value.bindings)};
}
function serialize(rows) { return JSON.stringify({schemaVersion: 1, bindings: normalize(rows)}, null, 2) + "\n"; }
