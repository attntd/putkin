.pragma library

// Selection is independent of rendering and of desktop icon themes.
function battery(value) {
    if (!value || value.percentage < 0) return "battery_android_question";
    const percent = Math.max(0, Math.min(100, value.percentage));
    if (value.charging) {
        if (percent < 30) return "battery_charging_20_2";
        if (percent < 50) return "battery_charging_30_2";
        if (percent < 60) return "battery_charging_50_2";
        if (percent < 80) return "battery_charging_60_2";
        if (percent < 100) return "battery_charging_80_2";
        return "battery_charging_full_2";
    }
    if (value.state === 4 || percent === 100) return "battery_android_full";
    // 0..9%, 10..24%, 25..39%, 40..54%, 55..69%, 70..84%, 85..99%.
    const level = percent < 10 ? 0 : Math.min(6, 1 + Math.floor((percent - 10) / 15));
    return "battery_android_" + level;
}

function wifi(strength) {
    const level = Number.isFinite(strength) ? Math.max(0, Math.min(1, strength)) : 0;
    return level < 0.25 ? "network_wifi_1_bar" : level < 0.5 ? "network_wifi_2_bar"
        : level < 0.75 ? "network_wifi_3_bar" : "network_wifi";
}

function network(value, includeEthernet) {
    if (includeEthernet && value && value.ethernetConnected) return "settings_ethernet";
    if (!value || !value.available || !value.wifiEnabled || !value.hardwareEnabled) return "signal_wifi_off";
    if (!value.activeWifi.length) return "signal_wifi_0_bar";
    return wifi(Math.max.apply(null, value.activeWifi.map(item => item.signalStrength)));
}

function notifications(value) {
    return value && value.dnd ? "notifications_off"
        : value && value.unreadCount > 0 ? "notifications_unread" : "notifications";
}

var applications = {
    "tether": "putkin_tether", "tether-gtk": "putkin_tether", "signal": "chat_bubble", "signal-desktop": "chat_bubble",
    "org.kde.dolphin": "folder", "dolphin": "folder", "yazi": "folder", "kitty": "terminal",
    "zen": "language", "zen-browser": "language", "chromium": "language", "firefox": "language",
    "chrome-heccpefhmgmcmihimnilmfenlceimcpm-default": "language", "ristu": "language",
    "btop": "monitoring", "btop++": "monitoring", "lstopo": "developer_board", "hwloc": "developer_board",
    "voxtype-configure": "mic", "voxtype": "mic", "audio-input-microphone": "mic",
    "localsend": "share", "mpv": "movie", "com.github.iwalton3.jellyfin-mpv-shim": "movie",
    "jellyfin mpv shim": "movie", "re.fossplant.songrec": "graphic_eq", "songrec": "graphic_eq",
    "guvcview": "videocam", "qv4l2": "videocam", "qvidcap": "videocam",
    "assistant": "help", "designer": "palette", "linguist": "translate", "qdbusviewer": "code",
    "cmake-gui": "code", "cmakesetup": "code", "nvim": "code", "neovim": "code",
    "org.fontforge.fontforge": "font_download", "cups": "print", "uuctl": "settings",
    "systemsettings": "settings", "kdesystemsettings": "settings", "qt6ct": "palette", "nwg-look": "palette",
    "preferences-system": "settings", "preferences-desktop-theme": "palette",
    "pavucontrol-qt": "volume_up", "multimedia-volume-control": "volume_up",
    "avahi-discover": "devices", "bssh": "terminal", "bvnc": "desktop_windows", "network-wired": "settings_ethernet"
};

function normalized(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "");
}

function application(id, title, icon, categories) {
    for (const value of [id, icon, title]) {
        const key = normalized(value);
        if (/^signal(?:[-_. ]|$)/.test(key)) return "chat_bubble";
        if (/^tether(?:[-_. ]|$)/.test(key)) return "putkin_tether";
        if (applications[key]) return applications[key];
    }
    const names = Array.from(categories || []);
    const types = {TerminalEmulator: "terminal", FileManager: "folder", WebBrowser: "language",
        InstantMessaging: "chat", TextEditor: "description", Development: "code", Graphics: "palette",
        AudioVideo: "movie", Audio: "music_note", Settings: "settings", Network: "devices", System: "developer_board"};
    for (const category of Object.keys(types)) if (names.indexOf(category) >= 0) return types[category];
    return "apps";
}

function launcher(entry) {
    if (!entry) return "apps";
    if (entry.kind === "application") return application(entry.id, entry.title, entry.icon, entry.application && entry.application.categories);
    if (entry.kind === "configuredCommand") return ({
        Shell: "terminal", Schowek: "content_paste", Wiadomości: "chat_bubble", Ustawienia: "settings",
        Dźwięk: "volume_up", Bateria: "battery_android_full", Powiadomienia: "notifications",
        Ekran: "desktop_windows", Sesja: "power_settings_new", Okna: "desktop_windows", Workspace: "desktop_windows"
    })[entry.subtitle] || "terminal";
    return entry.kind === "file" ? "description" : entry.kind === "clipboard" ? "content_paste"
        : entry.kind === "workspaceCommand" ? "desktop_windows" : "terminal";
}

function tray(item, signalUnread) {
    const symbol = item ? application(item.id || item.objectName, item.title, item.icon, []) : "apps";
    return symbol === "chat_bubble" && signalUnread ? "chat" : symbol;
}

function menu(icon) {
    const name = String(icon || "").toLowerCase();
    if (!name) return "";
    if (/preferences|settings/.test(name)) return "settings";
    if (/quit|exit|close/.test(name)) return "close";
    if (/refresh|reload/.test(name)) return "refresh";
    if (/sync/.test(name)) return "sync";
    if (/open/.test(name)) return "open_in_new";
    return "apps";
}
