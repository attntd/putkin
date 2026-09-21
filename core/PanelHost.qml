import QtQuick

QtObject {
    id: root
    required property var coordinator
    required property var loader
    property var launcher: null
    property var audio: null
    property var brightness: null
    property var nightLight: null
    property var caffeinate: null
    property var battery: null
    property var powerProfiles: null
    property var tray: null
    property var network: null
    property var bluetooth: null
    property var notifications: null
    property var sessionService: null
    property var signalService: null
    property var notificationController: null
    property Component trayMenuComponent: null
    property real anchorRight: 0
    property var screen: null
    property string surfaceId: ""
    property bool interactive: false
    readonly property bool loaded: loader.active
    // Never read item during asynchronous incubation.
    readonly property var window: loader.active ? loader.item : null
    readonly property int availableWidth: screen ? Math.max(1, screen.width - Metrics.panelGap * 2) : 1
    readonly property int availableHeight: screen ? Math.max(1, screen.height - Metrics.barHeight - Metrics.panelGap * 2) : 1
    readonly property real rightEdge: surfaceId === "trayMenu" || surfaceId === "trayOverflow"
        ? anchorRight : screen ? screen.width - Metrics.panelGap : 0
    readonly property int surfaceWidth: Math.min(surfaceId === "settings" ? Metrics.settingsWidth : surfaceId === "launcher" ? Metrics.launcherWidth : Metrics.panelWidth, availableWidth)
    readonly property int launcherPreviewSize: {
        if (surfaceId !== "launcher" || !launcher || !launcher.previewId) return 0;
        const size = Math.min(Metrics.launcherPreviewSize, availableHeight, availableWidth - surfaceWidth - Metrics.panelGap);
        return size >= Metrics.launcherPreviewMinimum ? size : 0;
    }
    readonly property int surfaceExtentWidth: surfaceWidth + (launcherPreviewSize ? Metrics.panelGap + launcherPreviewSize : 0)
    readonly property real surfaceX: (surfaceId === "power" || surfaceId === "launcher" || surfaceId === "settings") && screen
        ? Math.min((screen.width - surfaceWidth) / 2, screen.width - Metrics.panelGap - surfaceExtentWidth)
        : Math.max(Metrics.panelGap, Math.min(availableWidth + Metrics.panelGap
        - surfaceWidth, rightEdge - surfaceWidth))

    function surfaceY(height: real): real {
        return (surfaceId === "power" || surfaceId === "launcher" || surfaceId === "settings") && screen ? Math.max(Metrics.barHeight + Metrics.panelGap, (screen.height - height) / 2)
            : Metrics.barHeight + Metrics.panelGap;
    }

    function sync(): void {
        const session = coordinator.session;
        if (launcher && session && session.id === "launcher" && surfaceId === "launcher" && screen !== session.screen)
            launcher.setActive(false);
        if (launcher) {
            launcher.monitorName = session ? session.screen.name : "";
            launcher.setActive(session !== null && session.id === "launcher");
        }
        if (session) {
            if (powerProfiles && session.id === "battery") powerProfiles.refresh();
            if (brightness && session.id === "quickSettings") brightness.refresh();
            if (nightLight && session.id === "quickSettings") nightLight.refresh();
            if (sessionService && (session.id === "quickSettings" || session.id === "power")) sessionService.refresh();
            release.stop();
            if (screen !== session.screen || (surfaceId === "settings") !== (session.id === "settings")) {
                interactive = false;
                loader.activeAsync = false;
            }
            screen = session.screen;
            surfaceId = session.id;
            anchorRight = session.anchorRight;
            interactive = true;
            loader.activeAsync = true;
        } else {
            interactive = false;
            release.restart();
        }
    }

    readonly property Timer release: Timer {
        interval: Metrics.panelFade
        onTriggered: {
            if (!root.interactive) {
                root.loader.activeAsync = false;
                root.screen = null;
                root.surfaceId = "";
            }
        }
    }
    readonly property Connections changes: Connections {
        target: root.coordinator
        function onSessionChanged(): void { root.sync(); }
    }
    Component.onCompleted: sync()
}
