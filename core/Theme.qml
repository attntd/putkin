pragma Singleton

import QtQuick
import "Appearance.js" as Appearance

QtObject {
    property var appearance: Appearance.defaults().appearance
    readonly property color background: "#1e1e2e"
    readonly property color backgroundStrong: "#181825"
    readonly property color screenshotShade: "#55000000"
    readonly property color surface: "#313244"
    readonly property color surfaceHover: "#45475a"
    readonly property color border: "#45475a"
    readonly property color text: "#cdd6f4"
    readonly property color textMuted: "#a6adc8"
    readonly property color textDisabled: "#6c7086"
    readonly property color accent: appearance.accent
    readonly property color accentSecondary: appearance.accentSecondary
    // The onAccent role uses this name to avoid QML's on<Signal> syntax.
    readonly property color accentText: Appearance.foreground(appearance.accent)
    readonly property color accentSecondaryText: Appearance.foreground(appearance.accentSecondary)
    readonly property color accentBorder: Appearance.contrast(appearance.accent, String(backgroundStrong)) < 3 ? text : accent
    readonly property color accentSecondaryBorder: Appearance.contrast(appearance.accentSecondary, String(backgroundStrong)) < 3 ? text : accentSecondary
    readonly property color focus: accentBorder
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color error: "#f38ba8"
    readonly property string fontFamily: "JetBrainsMono Nerd Font Mono"
    function mix(a: color, b: color, position: real): color {
        const t = Math.max(0, Math.min(1, position));
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    function foreground(background: color): color { return Appearance.foreground(String(background)); }
}
