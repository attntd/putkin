.pragma library

// The single source of defaults, validation and accent contrast for Putkin.
function defaults() {
    return {schemaVersion: 1, appearance: {accent: "#cba6f7", accentSecondary: "#89b4fa"}};
}

var presets = [
    {name: "Mauve", color: "#cba6f7"}, {name: "Pink", color: "#f5c2e7"},
    {name: "Blue", color: "#89b4fa"}, {name: "Lavender", color: "#b4befe"},
    {name: "Peach", color: "#fab387"}, {name: "Teal", color: "#94e2d5"}
];

function isHex(value) { return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value); }
function copy(value) { return JSON.parse(JSON.stringify(value)); }
function object(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }
function knownKeys(value, keys) { return Object.keys(value).every(key => keys.indexOf(key) >= 0); }

function parse(text) {
    let value;
    try { value = JSON.parse(text); } catch (_) { return {error: "json"}; }
    if (!object(value)) return {error: "shape"};
    if (value.schemaVersion !== 1) return {error: "version"};
    if (!knownKeys(value, ["schemaVersion", "appearance"])) return {error: "unknown"};
    const result = defaults();
    if (value.appearance === undefined) return {value: result};
    const a = value.appearance;
    if (!object(a)) return {error: "shape"};
    if (!knownKeys(a, ["accent", "accentSecondary", "reducedMotion"])) return {error: "unknown"};
    for (const key of ["accent", "accentSecondary"]) {
        if (a[key] !== undefined) {
            if (!isHex(a[key])) return {error: "color"};
            result.appearance[key] = a[key].toLowerCase();
        }
    }
    if (a.reducedMotion !== undefined) {
        if (typeof a.reducedMotion !== "boolean") return {error: "motion"};
        // Accept the retired setting in existing files, without retaining it.
    }
    return {value: result};
}

function serialize(appearance) {
    return JSON.stringify({schemaVersion: 1, appearance: {
        accent: appearance.accent.toLowerCase(), accentSecondary: appearance.accentSecondary.toLowerCase()
    }}, null, 2) + "\n";
}

function luminance(hex) {
    const channels = [1, 3, 5].map(offset => {
        const s = parseInt(String(hex).slice(offset, offset + 2), 16) / 255;
        return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
    });
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

function contrast(a, b) {
    const x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

function foreground(hex) {
    return contrast(hex, "#000000") >= contrast(hex, "#ffffff") ? "#000000" : "#ffffff";
}

function observation(text, missing, error) {
    return {text: text, missing: missing, error: error,
        token: error ? "error:" + error : missing ? "missing" : "file:" + text};
}
