import QtQuick
import Quickshell
import "../../core"
import "../../components" as UI

// qmllint disable uncreatable-type
FloatingWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var controller
    title: "Wiadomości"
    screen: controller.screen
    implicitWidth: Math.min(1000, screen ? screen.width - 24 : 1000)
    implicitHeight: Math.min(720, screen ? screen.height - Metrics.barHeight - 24 : 720)
    minimumSize: Qt.size(280, 180)
    color: "transparent"
    visible: controller.loaded
    readonly property alias view: view
    UI.FadeScope {
        id: surface
        anchors.fill: parent
        shown: root.controller.interactive
        enabled: shown
        contentReady: view.width > 0 && view.height > 0
        MessagesView {
            id: view
            anchors.fill: parent
            hub: root.controller.hub
            readingEnabled: root.visible && !root.minimized && Window.active
                && root.controller.interactive && !root.controller.blocked && surface.opacity === 1
            onDismissed: root.controller.close()
        }
    }
    Connections {
        target: root.controller
        function onPresented(): void { Qt.callLater(() => view.focusInitial(root.controller.focusConversation)); }
    }
    Component.onCompleted: Qt.callLater(() => view.focusInitial(root.controller.focusConversation))
    onClosed: controller.close()
}
