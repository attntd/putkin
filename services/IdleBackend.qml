import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    required property var service
    required property var bridge
    property int dimSeconds: 180
    property int displaySeconds: 300
    property int lockSeconds: 360
    property int sleepSeconds: 900
    Component.onCompleted: Hyprland.refreshMonitors()
    function setEnabled(value: bool): bool {
        if (!Hyprland.usingLua) return false;
        Hyprland.dispatch('hl.dsp.dpms({action = "' + (value ? 'enable' : 'disable') + '"})');
        return true;
    }
    IdleMonitor {
        timeout: root.dimSeconds
        enabled: root.bridge.idleReady && !root.service.idleBlocked
        respectInhibitors: true
        onIsIdleChanged: { root.service.dim(isIdle); root.bridge.setIdleHint(isIdle); }
    }
    IdleMonitor {
        timeout: root.displaySeconds
        enabled: root.bridge.idleReady && !root.service.idleBlocked
        respectInhibitors: true
        onIsIdleChanged: root.service.screen(isIdle)
    }
    IdleMonitor {
        timeout: root.lockSeconds
        enabled: root.bridge.idleReady && !root.service.idleBlocked
        respectInhibitors: true
        onIsIdleChanged: root.service.lock(isIdle)
    }
    IdleMonitor {
        timeout: root.sleepSeconds
        enabled: root.bridge.idleReady && !root.service.idleBlocked && !root.service.sleepBlocked
        respectInhibitors: true
        onIsIdleChanged: root.service.suspend(isIdle)
    }
}
