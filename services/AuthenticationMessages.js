.pragma library

// Read only a directly declared fprintd timeout. An included/unknown stack or
// an unlimited timeout cannot supply an honest duration to the countdown.
function fingerprintTimeout(configuration) {
    const entries = String(configuration || "").split("\n").map(line => line.split("#")[0].trim())
        .filter(line => /^-?auth\s+(?:\[[^\]]+\]|\S+)\s+(?:\S*\/)?pam_fprintd\.so(?:\s|$)/.test(line));
    if (entries.length !== 1) return 0;
    const option = entries[0].match(/\btimeout=(\S+)/);
    if (!option) return 30000; // fprintd 1.94.5 default
    if (!/^-?\d+$/.test(option[1])) return 0;
    const seconds = Number(option[1]);
    return seconds > 0 && seconds <= 2147483 ? seconds * 1000 : 0;
}

// fprintd 1.94.5's installed English/Polish PAM catalogue. Never interpret
// arbitrary errors as a failed match or infer successful authentication here.
function fingerprint(message) {
    const text = String(message || "").trim();
    if (/^(Place your .* on |Swipe your .* across |Proszę umieścić .* na urządzeniu|Proszę przeciągnąć .* na urządzeniu)/.test(text)) return "ready";
    if (text === "Failed to match fingerprint" || text === "Dopasowanie odcisku palca się nie powiodło") return "mismatch";
    if (/^(Swipe was too short|Your finger was not centered|Remove your finger, and try|Place your finger on the reader again|Swipe your finger again|Przeciągnięcie było zbyt krótkie|Palec nie został wyśrodkowany|Proszę odsunąć palec|Proszę ponownie umieścić palec|Proszę ponownie przeciągnąć palec)/.test(text)) return "retry";
    if (/^(Verification timed out|Weryfikacja przekroczyła czas oczekiwania)$/.test(text)) return "timeout";
    return "";
}

function describe(source, mode, message, prompt) {
    const text = String(message || "");
    const combined = text + " " + String(prompt || "");
    const pin = /\bpin\b/i.test(combined);
    const yubi = /yubikey/i.test(combined);
    let context = text;
    let title = "Potwierdź operację", label = prompt || "Hasło", accept = "Potwierdź";
    if (source === "ssh") {
        if (mode === "none") return {title: yubi ? "Dotknij YubiKeya" : "Dotknij klucza", prompt: "", context: "Dotknij klucza, aby potwierdzić operację", mode: "touch", accept: ""};
        if (mode === "confirm") { title = "Zezwól na użycie klucza"; accept = "Zezwól"; }
        else if (pin) {
            title = yubi ? "Odblokuj YubiKey" : "Odblokuj klucz sprzętowy"; label = "PIN";
            if (/^Enter PIN for (YubiKey|authenticator|security key):?\s*$/i.test(text)) context = "Wprowadź PIN klucza";
        } else if (/passphrase|hasł[oa].*klucz/i.test(combined)) {
            title = "Odblokuj klucz SSH"; label = "Hasło klucza";
            const key = text.match(/^Enter passphrase for key ['"](.+)['"]:\s*$/);
            if (key) context = key[1];
        }
    } else if (source === "gpg") {
        if (pin) { title = yubi ? "Odblokuj YubiKey" : "Odblokuj klucz sprzętowy"; label = "PIN"; }
        else if (/\b(sign|signature|signing)\b|podpis/i.test(combined)) { title = "Podpisz kluczem GPG"; label = "Hasło klucza"; }
        else if (/decrypt|odszyfr/i.test(combined)) { title = "Odszyfruj dane"; label = "Hasło klucza"; }
        else label = prompt || "Hasło klucza";
    }
    return {title: title, prompt: label, context: context, mode: mode === "confirm" ? "confirm" : mode === "message" ? "message" : "input", accept: accept};
}
