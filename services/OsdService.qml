import QtQuick
import "../core"

QtObject {
    id: root
    required property var audio
    property var brightness: null
    required property var screens
    required property var monitorService
    required property var panelHost
    property var screen: null
    property string kind: "audio"
    readonly property real level: kind === "brightness" ? (brightness ? brightness.percent : 0) : audio && !audio.muted ? audio.volume : 0
    readonly property string label: kind === "brightness" ? qsTr("Jasność · ") + (brightness ? brightness.statusText : "") : audio ? audio.statusText : ""
    readonly property string symbol: kind === "brightness" ? "brightness_6" : audio && audio.muted ? "volume_off" : "volume_up"
    readonly property color fillColor: kind === "brightness" ? Theme.accentSecondary : Theme.accent
    readonly property bool visible: screen !== null
    property int timeout: Metrics.osdTimeout
    readonly property bool panelShowsAudio: panelHost.interactive && panelHost.loaded && panelHost.surfaceId === "quickSettings"
    readonly property bool audioPanelOpen: panelHost.interactive && panelHost.loaded && panelHost.surfaceId === "audio"

    function hide(): void { expiry.stop(); screen = null; }
    function show(monitor: string): void { showKind("audio", monitor); }
    function showKind(type: string, monitor: string): void {
        const source = type === "brightness" ? brightness : audio;
        if (!source || !source.available || panelShowsAudio || (type === "audio" && audioPanelOpen)) { hide(); return; }
        const target = screens.find(candidate => candidate.name === (monitor || monitorService.focusedMonitorName))
            || (screens.length ? screens[0] : null);
        if (!target || target.width < Metrics.space24 * 2 || target.height < Metrics.osdHeight + Metrics.space24) return;
        kind = type;
        screen = target;
        expiry.restart();
    }
    onScreensChanged: { if (screen && screens.indexOf(screen) < 0) hide(); }
    onPanelShowsAudioChanged: { if (panelShowsAudio) hide(); }
    onAudioPanelOpenChanged: { if (audioPanelOpen && kind === "audio") hide(); }
    readonly property Timer expiry: Timer { interval: root.timeout; onTriggered: root.hide() }
    readonly property Connections changes: Connections {
        target: root.audio
        function onFeedback(monitor: string): void { root.show(monitor); }
        function onAvailableChanged(): void { if (root.kind === "audio" && !root.audio.available) root.hide(); }
        function onDefaultOutputChanged(): void { if (root.kind === "audio") root.hide(); }
    }
    readonly property Connections brightnessChanges: Connections {
        target: root.brightness
        function onFeedback(monitor: string): void { root.showKind("brightness", monitor); }
        function onAvailableChanged(): void { if (root.kind === "brightness" && !root.brightness.available) root.hide(); }
    }
}
