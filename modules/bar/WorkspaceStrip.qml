pragma ComponentBehavior: Bound

import QtQuick
import "../../components" as UI
import "../../core"

Item {
    id: root
    required property var service
    required property string screenName
    property bool navigating: false
    property Item nextControl: null
    property bool windowedTooltips: false
    property int selectedId: -1
    readonly property int activeId: service.activeId(screenName)
    readonly property bool available: service.monitorAvailable(screenName)
    readonly property bool overflow: service.workspaces.count * Metrics.workspaceWidth > width
    readonly property alias list: list

    signal dismissed()

    implicitHeight: Metrics.barHeight
    enabled: available

    function selectIndex(index: int, takeFocus: bool): void {
        if (index < 0 || index >= service.workspaces.count)
            return;
        selectedId = service.workspaces.get(index).workspaceId;
        list.currentIndex = index;
        if (navigating || !overflow)
            list.positionViewAtIndex(index, ListView.Contain);
        if (takeFocus)
            Qt.callLater(focusSelection);
    }

    function focusSelection(): void {
        if (!navigating || !available)
            return;
        list.forceLayout();
        const button = list.currentItem as WorkspaceButton;
        if (button) {
            button.focusReason = Qt.TabFocusReason;
            button.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    function enter(): void {
        if (available)
            selectIndex(Math.max(0, service.indexOf(activeId)), true);
    }

    function syncSelection(): void {
        const keepFocus = list.activeFocus;
        const index = service.indexOf(navigating ? selectedId : activeId);
        selectIndex(index >= 0 ? index : Math.max(0, service.indexOf(activeId)), navigating && keepFocus);
    }

    function moveSelection(delta: int): void {
        if (delta > 0 && list.currentIndex === service.workspaces.count - 1 && nextControl) {
            nextControl.forceActiveFocus(Qt.TabFocusReason);
            return;
        }
        selectIndex(Math.max(0, Math.min(service.workspaces.count - 1, list.currentIndex + delta)), true);
    }

    function activate(id: int): void {
        if (service.activate(id, screenName))
            dismissed();
    }

    onNavigatingChanged: {
        if (navigating)
            enter();
        else {
            list.focus = false;
            syncSelection();
        }
    }
    onWidthChanged: Qt.callLater(syncSelection)
    Component.onCompleted: Qt.callLater(syncSelection)
    Connections {
        target: root.service
        function onUpdated(): void { root.syncSelection(); }
    }

    Text {
        id: pinned
        objectName: "activeWorkspace"
        visible: root.overflow && root.width >= Metrics.workspaceWidth * 2
        width: visible ? Metrics.workspaceWidth : 0
        height: parent.height
        text: root.activeId > 0 ? String(root.activeId) : "—"
        color: pinnedAccent.color
        UI.AccentCoordinates { id: pinnedAccent; item: pinned }
        font.family: Theme.fontFamily
        font.pixelSize: Metrics.fontSize
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Accessible.name: qsTr("Aktywny workspace: %1").arg(root.activeId)
    }

    UI.Button {
        id: previous
        objectName: "previousWorkspaces"
        x: pinned.width
        width: visible ? Metrics.barHeight : 0
        height: parent.height
        visible: root.overflow && root.width >= 160
        enabled: !list.atXBeginning
        text: "‹"
        contentItem: UI.Glyph { section: "bar"; symbol: "chevron_right"; rotation: 180; color: Theme.text }
        tooltip: qsTr("Poprzednie workspace — h")
        windowedTooltip: root.windowedTooltips
        padding: 0
        focusPolicy: Qt.NoFocus
        onClicked: list.contentX = Math.max(list.originX, list.contentX - Metrics.workspaceWidth * 3)
    }

    ListView {
        id: list
        objectName: "workspaceList"
        x: pinned.width + previous.width
        width: Math.max(Metrics.workspaceWidth, root.width - x - next.width)
        height: parent.height
        model: root.service.workspaces
        orientation: ListView.Horizontal
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        highlightMoveDuration: 0
        highlightFollowsCurrentItem: false
        currentIndex: -1
        delegate: WorkspaceButton {
            id: button
            required property int index
            objectName: "workspace-" + workspaceId
            width: Metrics.workspaceWidth
            height: list.height
            screenName: root.screenName
            windowedTooltip: root.windowedTooltips
            KeyNavigation.tab: index === root.service.workspaces.count - 1 ? root.nextControl : null
            KeyNavigation.backtab: index === 0 ? root.nextControl : null
            onClicked: root.activate(workspaceId)
            onActiveFocusChanged: {
                if (activeFocus) {
                    root.selectedId = workspaceId;
                    list.currentIndex = index;
                    list.positionViewAtIndex(index, ListView.Contain);
                }
            }
            Keys.onPressed: event => {
                if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier)
                    return;
                if (event.key === Qt.Key_H || event.key === Qt.Key_Left)
                    root.moveSelection(-1);
                else if (event.key === Qt.Key_L || event.key === Qt.Key_Right)
                    root.moveSelection(1);
                else if (event.key === Qt.Key_Home)
                    root.selectIndex(0, true);
                else if (event.key === Qt.Key_End)
                    root.selectIndex(root.service.workspaces.count - 1, true);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (!event.isAutoRepeat)
                        root.activate(button.workspaceId);
                } else if (event.key === Qt.Key_Escape)
                    root.dismissed();
                else
                    return;
                event.accepted = true;
            }
        }
    }

    UI.Button {
        id: next
        objectName: "nextWorkspaces"
        anchors.right: parent.right
        width: visible ? Metrics.barHeight : 0
        height: parent.height
        visible: root.overflow && root.width >= 160
        enabled: !list.atXEnd
        text: "›"
        contentItem: UI.Glyph { section: "bar"; symbol: "chevron_right"; color: Theme.text }
        tooltip: qsTr("Następne workspace — l")
        windowedTooltip: root.windowedTooltips
        padding: 0
        focusPolicy: Qt.NoFocus
        onClicked: list.contentX = Math.min(list.originX + list.contentWidth - list.width, list.contentX + Metrics.workspaceWidth * 3)
    }
}
