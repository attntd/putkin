import QtQuick

QtObject {
    id: root
    required property var screens
    required property var monitorService
    required property var barFocus
    required property var settings
    // A single assignment publishes a complete request to the host.
    property var session: null
    property string lastError: ""
    property string settingsSection: "appearance"
    property int settingsRequest: 0
    signal presented(string surface)
    readonly property string activeId: session ? session.id : ""
    readonly property string screenName: session ? session.screen.name : ""

    function chooseScreen(): var {
        return screens.find(screen => screen.name === monitorService.focusedMonitorName)
            || (screens.length > 0 ? screens[0] : null);
    }

    function open(id: string, screen: var, invoker: var, reason = undefined): bool {
        return present(id, screen, invoker, null, reason);
    }

    function openPower(action: string): bool {
        if (["poweroff", "reboot"].indexOf(action) < 0) return false;
        return present("power", null, null, null, undefined, action);
    }

    function openTray(item: var, screen: var, invoker: var, reason = undefined): bool {
        if (!item || !item.hasMenu || !item.menu) return false;
        return present("trayMenu", screen, invoker, item, reason);
    }

    function present(id: string, screen: var, invoker: var, item: var, reason: var, powerAction = ""): bool {
        if (["quickSettings", "settings", "trayOverflow", "trayMenu", "power", "launcher", "battery", "audio", "network", "bluetooth", "notifications"].indexOf(id) < 0) {
            lastError = "unknown-surface";
            return false;
        }
        const target = screen || chooseScreen();
        if (!target || screens.indexOf(target) < 0) {
            lastError = "screen-unavailable";
            return false;
        }
        if (target.width <= Metrics.panelGap * 2
                || target.height <= Metrics.barHeight + Metrics.panelGap * 2) {
            lastError = "screen-too-small";
            return false;
        }
        const previous = session && session.screen === target ? session : null;
        const focusReason = reason !== undefined ? reason : invoker && invoker.focusReason !== undefined
            ? invoker.focusReason : Qt.TabFocusReason;
        const restoreBar = focusReason !== Qt.MouseFocusReason
            && (previous ? previous.restoreBar : barFocus.screenName === target.name);
        const origin = invoker || (previous ? previous.invoker : null);
        const tray = id === "trayMenu" || id === "trayOverflow";
        const anchorRight = tray && invoker ? invoker.mapToItem(null, invoker.width, 0).x
            : tray && previous && previous.anchorRight ? previous.anchorRight : target.width - Metrics.panelGap;
        if (!session || session.id !== id || session.screen !== target) {
            settings.cancelEdit();
            if (id === "settings") settings.beginEdit();
        }
        barFocus.close();
        lastError = "";
        session = { id: id, screen: target, invoker: origin, restoreBar: restoreBar, focusReason: focusReason, trayItem: item, anchorRight: anchorRight, powerAction: powerAction,
            returnToOverflow: id === "trayMenu" && previous !== null
                && (previous.id === "trayOverflow" || previous.returnToOverflow === true) };
        presented(id);
        return true;
    }

    function toggle(id: string, screen: var, invoker: var): bool {
        const target = screen || chooseScreen();
        if (session && session.id === id && session.screen === target) {
            close(!invoker || invoker.focusReason !== Qt.MouseFocusReason);
            return true;
        }
        return open(id, target, invoker);
    }

    function close(restoreFocus: bool): void {
        const previous = session;
        settings.cancelEdit();
        session = null;
        if (restoreFocus && previous && previous.restoreBar
                && screens.indexOf(previous.screen) >= 0)
            barFocus.resume(previous.screen.name, previous.invoker);
    }

    function validate(): void {
        if (session && screens.indexOf(session.screen) < 0)
            close(false);
    }

    onScreensChanged: validate()
    readonly property Connections barChanges: Connections {
        target: root.barFocus
        function onEntered(_name: string): void { root.close(false); }
    }
}
