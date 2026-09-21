import QtQuick
import "Actions.js" as Actions

QtObject {
    id: root
    required property var coordinator
    required property var launcher
    required property var hyprland
    required property var windowActions
    required property var barFocus
    required property var notificationFocus
    required property var notifications
    required property var audio
    required property var brightness
    required property var sessionService
    property var messages: null
    property var screenshot: null
    property var powerProfiles: null
    property string lastError: ""
    function invoke(id: string, window: var, monitor: string): bool {
        if (!Actions.find(id)) { lastError = qsTr("Nieznane działanie."); return false; }
        lastError = "";
        if (id === "messages") {
            if (!messages || messages.blocked) return false;
            Qt.callLater(() => messages.open(monitor));
            return true;
        }
        const profile = ({powersaver: "power-saver", balanced: "balanced", performance: "performance"})[id];
        if (profile) {
            if (!powerProfiles || !powerProfiles.supports(profile)) {
                lastError = (powerProfiles && powerProfiles.availabilityText) || qsTr("Tryb pracy niedostępny");
                return false;
            }
            if (powerProfiles.busy) { lastError = qsTr("Trwa zmiana trybu pracy."); return false; }
            powerProfiles.setProfile(profile);
            return true;
        }
        if (id === "shutdown" || id === "poweroff" || id === "reboot") {
            const action = id === "shutdown" ? "poweroff" : id;
            const capability = sessionService.capability(action);
            if (sessionService.busy || !capability.available) {
                lastError = sessionService.busy ? qsTr("Trwa operacja sesji.") : capability.reason;
                return false;
            }
            Qt.callLater(() => {
                if (!coordinator.openPower(action)) lastError = coordinator.lastError;
            });
            return true;
        }
        if (id === "screenshot") {
            if (!screenshot || screenshot.blocked || screenshot.phase !== "idle" || screenshot.backend.busy) return false;
            // start() captures the original target before the launcher closes.
            const accepted = screenshot.start(window, monitor);
            if (accepted) { coordinator.close(false); barFocus.close(); }
            else lastError = screenshot.lastError;
            return accepted;
        }
        const panels = {settings: "settings", quickSettings: "quickSettings", audio: "audio", battery: "battery", power: "power"};
        // Defer focus handoffs until the old launcher's activation has closed it.
        if (panels[id]) {
            Qt.callLater(() => {
                const accepted = id === "quickSettings" ? coordinator.toggle(panels[id], null, null) : coordinator.open(panels[id], null, null);
                if (!accepted) lastError = coordinator.lastError;
            });
            return true;
        }
        if (id === "launcher" || id === "clipboard" || id === "commands") {
            Qt.callLater(() => {
                if (id === "launcher") coordinator.toggle("launcher", null, null);
                else if (coordinator.open("launcher", null, null)) launcher.startMode(id);
            });
            return true;
        }
        if (id === "bar") { Qt.callLater(() => barFocus.focusBar()); return true; }
        if (id === "notifications") { Qt.callLater(() => notificationFocus.openCenter()); return true; }
        if (id === "dnd") { notifications.dnd = !notifications.dnd; return true; }
        let accepted = false;
        let service = null;
        if (id === "volumeUp" || id === "volumeDown") { service = audio; accepted = audio.changeVolume(id === "volumeUp" ? 5 : -5, monitor); }
        else if (id === "mute") { service = audio; accepted = audio.toggleMute(monitor); }
        else if (id === "micMute") { service = audio.microphone; accepted = audio.microphone.toggleMute(monitor); }
        else if (id === "brightnessUp" || id === "brightnessDown") { service = brightness; accepted = brightness.change(id === "brightnessUp" ? 5 : -5, monitor); }
        else if (id === "lock" || id === "sleep" || id === "hibernate") {
            service = sessionService;
            accepted = sessionService.request(id === "sleep" ? "suspend" : id);
        }
        else {
            service = windowActions;
            accepted = windowActions.invoke(id, window, monitor);
        }
        if (!accepted) lastError = service.lastError || qsTr("Działanie niedostępne.");
        return accepted;
    }
}
