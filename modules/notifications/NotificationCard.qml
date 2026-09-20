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
    property bool scrollable: true
    property bool expanded: false
    readonly property bool expandable: expanded || summary.truncated || body.truncated
    readonly property string defaultAction: {
        const values = entry ? entry.actions : [];
        const action = values.find(value => value.identifier === "default") || values[0];
        return action ? action.identifier : "";
    }
    enabled: shown
    property Item previousControl: null
    property Item nextControl: null
    readonly property alias closeControl: close
    readonly property alias selectionControl: selection
    readonly property alias expandControl: expand
    readonly property var actionItems: actions
    readonly property alias viewport: flick
    implicitHeight: Math.min(scrollable ? Metrics.toastMaxHeight : Infinity, header.height + content.implicitHeight + Metrics.space12 * 3 + Metrics.space8)
    signal dismissRequested()
    signal actionRequested(string identifier)
    signal controlFocused(Item control)
    function actionAt(index: int): Item { return index >= 0 && index < actions.count ? actions.itemAt(index) : null; }
    function activate(): void { if (defaultAction) actionRequested(defaultAction); }
    function activateFromPointer(): void {
        selection.focusReason = Qt.MouseFocusReason;
        if (navigating) selection.forceActiveFocus(Qt.MouseFocusReason);
        activate();
    }
    function collapse(): void {
        expanded = false;
        flick.contentY = 0;
        selection.forceActiveFocus(Qt.TabFocusReason);
        Qt.callLater(() => root.reveal(selection));
    }
    function reveal(item: Item): void {
        controlFocused(item);
        if (!scrollable || item === selection || item === close || item === expand) return;
        const point = item.mapToItem(flick.contentItem, 0, 0);
        const margin = Metrics.focusOffset + Metrics.focusWidth;
        if (point.y - margin < flick.contentY) flick.contentY = Math.max(0, point.y - margin);
        else if (point.y + item.height + margin > flick.contentY + flick.height)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), point.y + item.height + margin - flick.height);
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_I && event.modifiers === Qt.NoModifier && root.expandable) {
            if (!event.isAutoRepeat) root.expanded = true;
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && root.expanded) {
            root.collapse();
            event.accepted = true;
        }
    }
    UI.NavigationButton {
        id: selection
        objectName: "notificationSelection"
        anchors.fill: parent
        padding: 0
        text: root.entry ? root.entry.summary : ""
        tooltip: ""
        focusPolicy: root.navigating ? Qt.StrongFocus : Qt.NoFocus
        upTarget: root.previousControl
        downTarget: root.nextControl
        rightTarget: expand.visible ? expand : close
        KeyNavigation.tab: rightTarget
        KeyNavigation.backtab: upTarget
        hasDetails: root.expandable
        onDetailsRequested: root.expanded = true
        onClicked: root.activate()
        onEnsureVisible: item => root.reveal(item)
        contentItem: Item {}
        background: UI.AccentRectangle {
            color: selection.down ? Theme.surfaceHover : Theme.backgroundStrong
            border.width: Metrics.borderWidth
            border.color: Theme.accentBorder
            accentOutline: true
            UI.FocusIndicator { control: selection; anchors.margins: Metrics.focusOffset }
        }
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
            width: Math.max(1, parent.width - appIcon.width - timeLabel.width - close.width - parent.spacing * 3 - (expand.visible ? expand.width + parent.spacing : 0))
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
            id: expand
            objectName: "notificationExpand"
            width: Metrics.controlHeight
            visible: root.expandable
            padding: 0
            tooltip: ""
            Accessible.name: root.expanded ? qsTr("Zwiń powiadomienie") : qsTr("Rozwiń powiadomienie")
            contentItem: UI.Glyph { section: "notification"; symbol: "expand_more"; rotation: root.expanded ? 180 : 0; color: expand.foreground }
            background: Rectangle {
                border.width: 0
                color: expand.down ? Theme.border : expand.hovered ? Theme.surfaceHover : "transparent"
                UI.FocusIndicator { control: expand }
            }
            focusPolicy: root.navigating ? Qt.StrongFocus : Qt.NoFocus
            leftTarget: selection
            rightTarget: close
            upTarget: root.previousControl
            downTarget: root.nextControl
            KeyNavigation.tab: close
            KeyNavigation.backtab: selection
            onClicked: {
                root.expanded = !root.expanded;
                flick.contentY = 0;
                selection.focusReason = focusReason;
                if (root.navigating) selection.forceActiveFocus(focusReason);
            }
            onEnsureVisible: item => root.reveal(item)
        }
        UI.NavigationButton {
            id: close
            objectName: "notificationClose"
            width: Metrics.controlHeight
            padding: 0
            text: "×"
            contentItem: UI.Glyph { section: "notification"; symbol: "close"; strokeWidth: 0.75; color: close.foreground }
            background: Rectangle {
                border.width: 0
                color: close.down ? Theme.border : close.hovered ? Theme.surfaceHover : "transparent"
                UI.FocusIndicator { control: close }
            }
            tooltip: qsTr("Zamknij powiadomienie")
            Accessible.name: tooltip
            focusPolicy: root.navigating ? Qt.StrongFocus : Qt.NoFocus
            leftTarget: expand.visible ? expand : selection
            upTarget: root.previousControl
            downTarget: root.actionAt(0) || root.nextControl
            KeyNavigation.tab: downTarget
            KeyNavigation.backtab: leftTarget
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
        wheelEnabled: root.scrollable
        focusPolicy: Qt.NoFocus
        Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        Controls.ScrollBar.vertical.policy: root.scrollable ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
        Flickable {
            id: flick
            objectName: "notificationContent"
            clip: true
            interactive: root.scrollable
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: content.height + content.y * 2
            Column {
                id: content
                x: Metrics.focusOffset + Metrics.focusWidth
                y: x
                width: Math.max(1, flick.width - x * 2)
                spacing: Metrics.space8
                Column {
                    width: parent.width
                    spacing: Metrics.space8
                    TapHandler { onTapped: root.activateFromPointer() }
                    UI.PanelText {
                        id: summary
                        objectName: "notificationSummary"
                        width: parent.width
                        text: root.entry ? root.entry.summary : ""
                        textFormat: Text.PlainText
                        font.bold: true
                        maximumLineCount: root.expanded ? 2147483647 : 3
                        elide: Text.ElideRight
                        wrapMode: Text.WrapAnywhere
                    }
                    UI.PanelText {
                        id: body
                        objectName: "notificationBody"
                        width: parent.width
                        visible: text.length > 0
                        text: root.entry ? root.entry.body : ""
                        textFormat: Text.PlainText
                        color: Theme.textMuted
                        maximumLineCount: root.expanded ? 2147483647 : 6
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
                            upTarget: index > 1 ? root.actionAt(index - 2) : selection
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
