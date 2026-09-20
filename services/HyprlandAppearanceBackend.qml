import QtQuick
import Quickshell.Hyprland
import "../core"

QtObject {
    id: root
    readonly property bool ready: Hyprland.usingLua
    signal reloaded()

    function apply(primary: color, secondary: color, inactive: color, width: int, radius: int): void {
        // Hyprland 0.56.2 weights normalized y by sin(angle), x by 1-sin(angle).
        // 30 degrees therefore matches the shell's (x/width + y/height)/2.
        // Its interpolation is Oklab; ten sRGB samples match Qt's color field.
        const stops = [];
        for (let index = 0; index < 10; ++index)
            stops.push('"rgba(' + String(Theme.mix(primary, secondary, index / 9)).slice(1) + 'ff)"');
        const active = '{colors={' + stops.join(",") + '},angle=30}';
        const neutral = '"rgba(' + String(inactive).slice(1) + 'ff)"';
        Hyprland.dispatch('function() hl.config({general={border_size=' + width + ',col={active_border=' + active
            + ',inactive_border=' + neutral + ',nogroup_border_active=' + active + ',nogroup_border=' + neutral
            + '}},decoration={rounding=' + radius + '},group={col={border_active=' + active
            + ',border_inactive=' + neutral + ',border_locked_active=' + active + ',border_locked_inactive=' + neutral + '}}}) end');
    }
    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void { if (event.name === "configreloaded") root.reloaded(); }
    }
}
