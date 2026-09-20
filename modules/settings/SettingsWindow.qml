import QtQuick
import Quickshell
import "../../core"
import "../quicksettings"

// qmllint disable uncreatable-type
FloatingWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var host
    title: qsTr("Ustawienia")
    screen: host.screen
    implicitWidth: host.surfaceWidth
    implicitHeight: Math.min(Metrics.settingsHeight, host.availableHeight)
    minimumSize: Qt.size(280, 180)
    color: Theme.backgroundStrong
    visible: host.loaded && host.interactive && surface.page !== null
    PanelSurface { id: surface; objectName: "settingsSurface"; anchors.fill: parent; host: root.host }
    onClosed: { if (host.window === root && host.interactive) host.coordinator.close(true); }
}
