import QtQuick

QtObject {
    id: root
    required property var brightness
    required property var session
    required property var display
    property bool idleBlocked: false
    property bool sleepBlocked: false
    property bool dimmed: false
    property real restorePercent: -1
    property string restoreDevice: ""
    property bool displaysOff: false
    property bool suspendSent: false
    property string lastError: ""
    function dim(idle: bool): void {
        if (idle) {
            if (idleBlocked || dimmed || !brightness.available || brightness.busy) return;
            restorePercent = brightness.percent;
            restoreDevice = brightness.device;
            // Do not brighten an already dimmer display.
            if (restorePercent <= 10) return;
            dimmed = brightness.setIdlePercent(10);
        } else restore();
    }
    function restore(): void {
        if (!dimmed) return;
        dimmed = false;
        if (brightness.available && brightness.device === restoreDevice && restorePercent >= 1)
            brightness.setIdlePercent(restorePercent);
        restorePercent = -1;
        restoreDevice = "";
    }
    function screen(idle: bool): void {
        if (idle && idleBlocked) return;
        if (displaysOff === idle) return;
        if (display.setEnabled(!idle)) displaysOff = idle;
        else lastError = qsTr("Nie udało się zmienić stanu ekranów.");
    }
    function lock(idle: bool): void {
        if (idle && !idleBlocked) session.request("lock");
    }
    function suspend(idle: bool): void {
        if (!idle) { suspendSent = false; return; }
        if (idleBlocked || sleepBlocked || suspendSent || !session.capability("idleSuspend").available) return;
        suspendSent = session.request("idleSuspend");
    }
    function resume(): void {
        // Force DPMS on even if the compositor changed its state during sleep.
        display.setEnabled(true);
        displaysOff = false;
        suspendSent = false;
        restore();
    }
    onIdleBlockedChanged: {
        if (idleBlocked) { screen(false); restore(); suspendSent = false; }
    }
}
