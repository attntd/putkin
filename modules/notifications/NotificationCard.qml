pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

UI.FadeScope {
    id: root
    readonly property bool accentScope: true
    required property var entry
    property bool navigating: false
    enabled: shown
    property Item previousControl: null
    property Item nextControl: null
    readonly property alias closeControl: close
    readonly property var actionItems: actions
    readonly property alias viewport: flick
    implicitHeight: Math.min(Metrics.toastMaxHeight, header.height + content.implicitHeight + Metrics.space12 * 3 + Metrics.space8)
    signal dismissRequested()
    signal actionRequested(string identifier)
    signal controlFocused(Item control)
    function actionAt(index: int): Item { return index >= 0 && index < actions.count ? actions.itemAt(index) : null; }
    function reveal(item: Item): void {
        controlFocused(item);
        if (item === close) return;
        const point = item.mapToItem(flick.contentItem, 0, 0);
        const margin = Metrics.focusOffset + Metrics.focusWidth;
        if (point.y - margin < flick.contentY) flick.contentY = Math.max(0, point.y - margin);
        else if (point.y + item.height + margin > flick.contentY + flick.height)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), point.y + item.height + margin - flick.height);
    }
    UI.AccentRectangle {
        anchors.fill: parent
        color: Theme.backgroundStrong
        border.width: Metrics.borderWidth
        border.color: Theme.accentBorder
        accentOutline: true
    }
    Row {
        id: header
        x: Metrics.space12
        y: Metrics.space12
        width: parent.width - x * 2
        height: Metrics.controlHeight
        spacing: Metrics.space8
        UI.Glyph {
            id: appIcon
            section: "notification"
            width: slotSize; height: slotSize; y: (parent.height - height) / 2
            symbol: root.entry ? root.entry.iconName || "apps" : "apps"
        }
        UI.PanelText {
            width: Math.max(1, parent.width - appIcon.width - timeLabel.width - close.width - parent.spacing * 3)
            height: parent.height
            text: root.entry ? (root.entry.critical ? qsTr("Pilne · ") : "") + root.entry.appName : ""
            textFormat: Text.PlainText
            color: root.entry && root.entry.critical ? Theme.error : Theme.textMuted
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            font.pixelSize: Metrics.smallFontSize
        }
        UI.PanelText {
            id: timeLabel
            height: parent.height
            text: root.entry ? Qt.formatTime(new Date(root.entry.receivedAt), "HH:mm") : ""
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            color: Theme.textMuted
            font.pixelSize: Metrics.smallFontSize
        }
        UI.NavigationButton {
            id: close
            objectName: "notificationClose"
            width: Metrics.controlHeight
            padding: 0
            text: "×"
            contentItem: UI.Glyph { section: "notification"; symbol: "close"; color: close.foreground }
            tooltip: qsTr("Zamknij powiadomienie")
            Accessible.name: tooltip
            focusPolicy: root.navigating ? Qt.StrongFocus : Qt.NoFocus
            upTarget: root.previousControl
            downTarget: root.actionAt(0) || root.nextControl
            KeyNavigation.tab: downTarget
            KeyNavigation.backtab: upTarget
            onClicked: root.dismissRequested()
            onEnsureVisible: item => root.reveal(item)
        }
    }
    Controls.ScrollView {
        x: Metrics.space12 - Metrics.focusOffset - Metrics.focusWidth
        y: header.y + header.height + Metrics.space4
        width: parent.width - x * 2
        height: Math.max(1, parent.height - y - x)
        contentWidth: availableWidth
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        Flickable {
            id: flick
            objectName: "notificationContent"
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: content.height + content.y * 2
            Column {
                id: content
                x: Metrics.focusOffset + Metrics.focusWidth
                y: x
                width: Math.max(1, flick.width - x * 2)
                spacing: Metrics.space8
                UI.PanelText {
                    objectName: "notificationSummary"
                    width: parent.width
                    text: root.entry ? root.entry.summary : ""
                    textFormat: Text.PlainText
                    font.bold: true
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    wrapMode: Text.WrapAnywhere
                }
                UI.PanelText {
                    objectName: "notificationBody"
                    width: parent.width
                    visible: text.length > 0
                    text: root.entry ? root.entry.body : ""
                    textFormat: Text.PlainText
                    color: Theme.textMuted
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    wrapMode: Text.WrapAnywhere
                }
                Image {
                    objectName: "notificationImage"
                    width: parent.width
                    height: Metrics.toastImageHeight
                    visible: source.toString().length > 0 && status !== Image.Error
                    source: root.entry ? root.entry.imageSource : ""
                    sourceSize: Qt.size(Metrics.toastWidth, Metrics.toastImageHeight)
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    // The 0.3.1 qsimage provider references Notification-owned
                    // buffers. Only independent file images may load on a worker.
                    asynchronous: source.toString().startsWith("file:")
                }
                Grid {
                    id: actionGrid
                    width: parent.width
                    columns: 2
                    spacing: Metrics.space12
                    Repeater {
                        id: actions
                        model: root.entry ? root.entry.actions : []
                        delegate: UI.NavigationButton {
                            id: actionButton
                            required property int index
                            required property var modelData
                            objectName: "notificationAction-" + index
                            width: (actionGrid.width - Metrics.space12) / 2
                            text: modelData.text
                            focusPolicy: root.navigating ? Qt.StrongFocus : Qt.NoFocus
                            contentItem: Text {
                                text: actionButton.text; textFormat: Text.PlainText
                                color: actionButton.foreground; font: actionButton.font
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            leftTarget: index % 2 ? root.actionAt(index - 1) : null
                            rightTarget: index % 2 === 0 ? root.actionAt(index + 1) : null
                            upTarget: index > 1 ? root.actionAt(index - 2) : close
                            downTarget: root.actionAt(index + 2) || root.nextControl
                            KeyNavigation.tab: root.actionAt(index + 1) || root.nextControl || close
                            KeyNavigation.backtab: index > 0 ? root.actionAt(index - 1) : close
                            onClicked: root.actionRequested(modelData.identifier)
                            onEnsureVisible: item => root.reveal(item)
                        }
                    }
                }
            }
        }
    }
}
