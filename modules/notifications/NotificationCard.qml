pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

UI.FadeScope {
    id: root
    readonly property bool accentScope: true
    required property var entry
    property var service: null
    readonly property var messageReference: entry ? entry.messageReference || null : null
    readonly property bool redacted: !!messageReference && !!service && service.locked
    readonly property var presentation: messageReference && service
        ? service.history.find(row => row.historyKey === entry.historyKey) || {summary: "Signal", body: ""} : entry
    readonly property var replySession: service ? service.messageSession(messageReference) : null
    property bool replyExpanded: false
    readonly property NotificationReply replyEditor: replyLoader.item as NotificationReply
    function focusReply(reason = Qt.TabFocusReason): void {
        if (!replySession || redacted) return;
        replyExpanded = true;
        Qt.callLater(() => { if (root.replyEditor) root.replyEditor.focusEditor(reason); });
    }
    property bool navigating: false
    property bool toast: false
    property bool scrollable: true
    property bool expanded: false
    // Expanded history can exceed the GPU texture size. The enclosing panel
    // already composites its visible viewport for the shared fade.
    layer.enabled: visible && (toast || !expanded)
    readonly property bool textClipped: summary.truncated || body.truncated || (scrollable
        && content.y + (body.visible ? body.y + body.height : summary.y + summary.height) > flick.height + 1)
    readonly property bool expandable: expanded || textClipped
    readonly property string defaultAction: {
        const values = messageReference && service ? service.messageActions(messageReference) : entry ? entry.actions : [];
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
    readonly property Item firstHeaderControl: mute.visible ? mute : expand.visible ? expand : close
    property Item lastHeaderControl: null
    readonly property Item returnHeaderControl: lastHeaderControl && lastHeaderControl.visible ? lastHeaderControl : firstHeaderControl
    readonly property Item firstActionControl: actionAt(0) || (replyEditor ? replyEditor.editor : null)
    implicitHeight: Math.min(scrollable ? (replyExpanded ? 420 : Metrics.toastMaxHeight) : Infinity, header.height + content.implicitHeight + Metrics.space12 * 3 + Metrics.space8)
    signal dismissRequested()
    signal archiveRequested()
    signal actionRequested(string identifier)
    signal controlFocused(Item control)
    function actionAt(index: int): Item { return index >= 0 && index < actions.count ? actions.itemAt(index) : null; }
    function actionBelow(index: int): Item {
        const nextRow = (Math.floor(index / 2) + 1) * 2;
        return nextRow < actions.count ? actionAt(Math.min(index + 2, actions.count - 1))
            : replyEditor ? replyEditor.editor : null;
    }
    function activate(expandFirst = true): void {
        if (expandFirst && !expanded && textClipped) { expanded = true; return; }
        if (defaultAction || (entry && entry.applicationId)) actionRequested(defaultAction);
    }
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
        if (item === mute || item === expand || item === close) lastHeaderControl = item;
        controlFocused(item);
        if (!scrollable || item === selection || item === close || item === expand || item === mute) return;
        const point = item.mapToItem(flick.contentItem, 0, 0);
        const margin = Metrics.focusOffset + Metrics.focusWidth;
        if (point.y - margin < flick.contentY) flick.contentY = Math.max(0, point.y - margin);
        else if (point.y + item.height + margin > flick.contentY + flick.height)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), point.y + item.height + margin - flick.height);
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_D && event.modifiers === Qt.NoModifier && !DismissKeys.textFocused(root)) {
            if (!event.isAutoRepeat) root.dismissRequested();
            event.accepted = true;
        } else if (root.toast && DismissKeys.matches(event, root) && !DismissKeys.textFocused(root)) {
            if (!event.isAutoRepeat) root.archiveRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_I && event.modifiers === Qt.NoModifier && root.expandable) {
            if (!event.isAutoRepeat) root.expanded = true;
            event.accepted = true;
        } else if (root.expanded && DismissKeys.matches(event, root)) {
            root.collapse();
            event.accepted = true;
        }
    }
    UI.NavigationButton {
        id: selection
        objectName: "notificationSelection"
        anchors.fill: parent
        padding: 0
        text: root.redacted ? "Signal" : root.presentation ? root.presentation.summary : ""
        tooltip: ""
        focusPolicy: root.navigating ? Qt.StrongFocus : Qt.NoFocus
        upTarget: root.previousControl
        downTarget: root.nextControl
        rightTarget: root.firstHeaderControl
        KeyNavigation.tab: rightTarget
        KeyNavigation.backtab: upTarget
        hasDetails: root.expandable
        onDetailsRequested: root.expanded = true
        onClicked: root.activate(!root.toast || focusReason === Qt.MouseFocusReason)
        onEnsureVisible: item => root.reveal(item)
        contentItem: Item {}
        background: UI.AccentRectangle {
            color: selection.down ? Theme.surfaceHover : Theme.backgroundStrong
            border.width: Metrics.borderWidth
            border.color: Theme.border
            UI.FocusIndicator { control: selection }
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
            width: Math.max(1, parent.width - appIcon.width - timeLabel.width - close.width - (mute.visible ? mute.width + parent.spacing : 0) - parent.spacing * 3 - (expand.visible ? expand.width + parent.spacing : 0))
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
            id: mute
            objectName: "notificationMute"
            visible: !!root.messageReference && !!root.service && root.service.messageActions(root.messageReference).length > 0
            width: Metrics.controlHeight
            padding: 0
            readonly property bool muted: visible && root.service.messaging.conversationMuted(root.messageReference)
            text: muted ? qsTr("Włącz powiadomienia") : qsTr("Wycisz")
            Accessible.name: text
            contentItem: UI.Glyph { section: "notification"; symbol: mute.muted ? "notifications_off" : "notifications"; color: mute.foreground }
            focusPolicy: root.navigating ? Qt.StrongFocus : Qt.NoFocus
            leftTarget: selection
            rightTarget: expand.visible ? expand : close
            downTarget: root.firstActionControl
            KeyNavigation.tab: rightTarget
            KeyNavigation.backtab: selection
            onClicked: root.actionRequested("mute")
            onEnsureVisible: item => root.reveal(item)
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
            leftTarget: mute.visible ? mute : selection
            rightTarget: close
            downTarget: root.firstActionControl
            KeyNavigation.tab: close
            KeyNavigation.backtab: leftTarget
            onClicked: {
                root.expanded = !root.expanded;
                flick.contentY = 0;
                Qt.callLater(() => root.reveal(expand));
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
            leftTarget: expand.visible ? expand : mute.visible ? mute : selection
            downTarget: root.firstActionControl
            KeyNavigation.tab: downTarget || root.nextControl || selection
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
            TapHandler {
                onTapped: eventPoint => {
                    // Explicit action buttons own their clicks; the rest of the
                    // viewport, including its padding and gaps, activates the card.
                    for (let index = 0; index < actions.count; ++index) {
                        const button = root.actionAt(index);
                        if (button && button.visible && button.contains(button.mapFromItem(flick, eventPoint.position.x, eventPoint.position.y))) return;
                    }
                    if (root.replyEditor && root.replyEditor.contains(root.replyEditor.mapFromItem(flick, eventPoint.position.x, eventPoint.position.y))) return;
                    root.activateFromPointer();
                }
            }
            Column {
                id: content
                x: Metrics.focusOffset + Metrics.focusWidth
                y: x
                width: Math.max(1, flick.width - x * 2)
                spacing: Metrics.space8
                Column {
                    width: parent.width
                    spacing: Metrics.space8
                    UI.PanelText {
                        id: summary
                        objectName: "notificationSummary"
                        width: parent.width
                        text: root.redacted ? "Signal" : root.presentation ? root.presentation.summary : ""
                        textFormat: Text.PlainText
                        font.bold: true
                        maximumLineCount: root.expanded ? 2147483647 : 3
                        elide: root.expanded ? Text.ElideNone : Text.ElideRight
                        wrapMode: Text.WrapAnywhere
                    }
                    UI.PanelText {
                        id: body
                        objectName: "notificationBody"
                        width: parent.width
                        visible: text.length > 0
                        text: root.redacted ? qsTr("Nowa wiadomość") : root.presentation ? root.presentation.body : ""
                        textFormat: Text.PlainText
                        color: Theme.textMuted
                        maximumLineCount: root.expanded ? 2147483647 : 6
                        elide: root.expanded ? Text.ElideNone : Text.ElideRight
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
                    visible: actions.count > 0
                    columns: 2
                    spacing: Metrics.space12
                    Repeater {
                        id: actions
                        // The card invokes default; only additional actions need buttons.
                        model: root.messageReference && root.service ? root.service.messageActions(root.messageReference) : root.entry ? root.entry.actions.filter(action => action.identifier !== "default") : []
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
                            leftTarget: index % 2 ? root.actionAt(index - 1) : selection
                            rightTarget: index % 2 === 0 ? root.actionAt(index + 1) : null
                            upTarget: index > 1 ? root.actionAt(index - 2) : root.returnHeaderControl
                            downTarget: root.actionBelow(index)
                            KeyNavigation.tab: root.actionAt(index + 1) || (root.replyEditor ? root.replyEditor.editor : root.nextControl) || close
                            KeyNavigation.backtab: index > 0 ? root.actionAt(index - 1) : close
                            onClicked: root.actionRequested(modelData.identifier)
                            onEnsureVisible: item => root.reveal(item)
                        }
                    }
                }
                Loader {
                    id: replyLoader
                    width: parent.width
                    active: root.replyExpanded && !!root.replySession && !root.redacted && root.shown
                    visible: active
                    sourceComponent: NotificationReply {
                        session: root.replySession
                        previousControl: root.actionAt(actions.count - 1) || close
                        nextControl: root.nextControl || close
                        onControlFocused: item => root.reveal(item)
                        onCollapsed: { root.replyExpanded = false; close.forceActiveFocus(Qt.TabFocusReason); }
                    }
                }
            }
        }
    }
}
