import QtQml
import Quickshell.Hyprland

QtObject {
    required property var service
    property string lastError: ""
    function invoke(action: string, window: var, monitor: string): bool {
        lastError = "";
        if (!service.available || !Hyprland.usingLua) { lastError = qsTr("Hyprland Lua niedostępny."); return false; }
        const workspace = /^(moveWorkspace|workspace)(10|[1-9])$/.exec(action);
        const direction = /^(focus|move)(Left|Down|Up|Right)$/.exec(action);
        const needsWindow = !workspace || workspace[1] === "moveWorkspace";
        if (needsWindow && !service.liveWindow(window)) { lastError = qsTr("Wybrane okno jest niedostępne."); return false; }
        const selector = needsWindow ? 'window = "address:0x' + window.address.replace(/^0x/, "") + '"' : "";
        let request = "";
        if (workspace) {
            if (workspace[1] === "moveWorkspace") request = 'hl.dsp.window.move({workspace = "' + workspace[2] + '", follow = false, ' + selector + '})';
            else {
                if (!service.monitorAvailable(monitor)) { lastError = qsTr("Monitor niedostępny."); return false; }
                service.backend.focusMonitor(monitor);
                request = 'hl.dsp.focus({workspace = "' + workspace[2] + '", on_current_monitor = true})';
            }
        } else if (direction) {
            if (direction[1] === "focus") {
                Hyprland.dispatch('hl.dsp.focus({' + selector + '})');
                request = 'hl.dsp.focus({direction = "' + direction[2].toLowerCase() + '"})';
            } else request = 'hl.dsp.window.move({direction = "' + direction[2].toLowerCase() + '", ' + selector + '})';
        } else if (action === "closeWindow") request = 'hl.dsp.window.close({' + selector + '})';
        else if (action === "floating") request = 'hl.dsp.window.float({action = "toggle", ' + selector + '})';
        else if (action === "fullscreen") request = 'hl.dsp.window.fullscreen({action = "toggle", mode = "fullscreen", ' + selector + '})';
        else { lastError = qsTr("Nieznane działanie Hyprlanda."); return false; }
        Hyprland.dispatch(request);
        return true;
    }
}
