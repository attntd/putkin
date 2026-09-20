import QtQuick

QtObject {
    id: root
    required property var service
    required property var loader
    property var screen: null
    readonly property bool loaded: loader.active
    readonly property var window: loader.active ? loader.item : null
    function sync(): void {
        if (service.visible) {
            release.stop();
            screen = service.screen;
            loader.activeAsync = true;
        } else release.restart();
    }
    readonly property Timer release: Timer {
        interval: Metrics.panelFade
        onTriggered: { root.loader.activeAsync = false; root.screen = null; }
    }
    readonly property Connections changes: Connections {
        target: root.service
        function onVisibleChanged(): void { root.sync(); }
    }
    Component.onCompleted: sync()
}
