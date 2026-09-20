pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../core/Icons.js" as Icons
import "../../components" as UI
import "../../services" as Services

UI.NavigationButton {
    id: root
    required property var trayItem
    property bool showLabel: false
    readonly property bool signalItem: Icons.tray(trayItem) === "chat_bubble"
    readonly property bool signalUnread: signalState.item ? (signalState.item as Services.SignalTrayState).unread : false
    signal primaryRequested()
    signal secondaryRequested()
    signal menuRequested()
    text: trayItem ? trayItem.title || trayItem.tooltipTitle || (trayItem["id"] || trayItem.objectName) || qsTr("Aplikacja w zasobniku") : ""
    tooltip: (trayItem ? trayItem.tooltipTitle || text : text)
        + (trayItem && trayItem.tooltipDescription ? "\n" + trayItem.tooltipDescription : "")
    padding: showLabel ? Metrics.space8 : 0
    implicitWidth: Metrics.trayButtonWidth
    implicitHeight: Metrics.barHeight
    onClicked: primaryRequested()
    // Right/middle clicks do not replace the standard Qt left-click handler.
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.menuRequested() }
    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: root.secondaryRequested() }
    Keys.onMenuPressed: menuRequested()
    Shortcut { sequence: "Shift+F10"; enabled: root.activeFocus; onActivated: root.menuRequested() }
    Shortcut { sequence: "Shift+Return"; enabled: root.activeFocus; onActivated: root.secondaryRequested() }
    Loader {
        id: signalState
        active: root.signalItem
        sourceComponent: Services.SignalTrayState {
            source: root.trayItem ? root.trayItem.icon : ""
            attention: root.trayItem !== null && root.trayItem.status === 2
        }
    }
    contentItem: Item {
        UI.Glyph {
            id: icon
            objectName: "trayApplicationIcon"
            x: root.showLabel ? 0 : (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            section: root.showLabel ? "list" : "bar"
            width: slotSize; height: slotHeight
            symbol: Icons.tray(root.trayItem, root.signalUnread)
            color: root.showLabel ? root.foreground : Theme.text
        }
        Text {
            anchors.left: icon.right; anchors.leftMargin: Metrics.space8
            anchors.right: parent.right; height: parent.height
            visible: root.showLabel
            text: root.text; textFormat: Text.PlainText
            font: root.font; color: root.foreground
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        Rectangle {
            objectName: "trayAttentionDot"
            width: 4; height: 4; anchors.right: parent.right; anchors.top: parent.top
            color: root.showLabel ? Theme.warning : Theme.text
            visible: !root.signalItem && root.trayItem !== null && root.trayItem.status === 2
        }
    }
}
