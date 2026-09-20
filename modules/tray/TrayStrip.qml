pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../components" as UI

FocusScope {
    id: root
    property var tray: null
    property int capacity: 4
    property Item previousControl: null
    property Item nextControl: null
    property bool windowedTooltips: false
    property var focusedItem: null
    readonly property var items: tray ? tray.items.values : []
    readonly property var visibleItems: items.filter(item => item.status !== 0)
    readonly property int directCount: Math.min(capacity, visibleItems.length)
    readonly property bool overflow: visibleItems.length > directCount
    readonly property Item firstControl: directCount > 0 ? buttonFor(visibleItems[0]) : overflow ? more : nextControl
    readonly property Item lastControl: overflow ? more : directCount > 0 ? buttonFor(visibleItems[directCount - 1]) : previousControl
    width: (directCount + (overflow ? 1 : 0)) * Metrics.trayButtonWidth
    height: Metrics.barHeight
    signal menuRequested(var item, Item invoker)
    signal overflowRequested(Item invoker)
    signal activationRequested(var item, bool secondary)
    signal dismissed()

    function buttonFor(item: var): Item { return buttons.count > 0 ? buttons.itemAt(items.indexOf(item)) : null; }
    function adjacent(item: var, delta: int): Item {
        const index = visibleItems.indexOf(item) + delta;
        return index < 0 ? previousControl : index >= directCount ? (overflow ? more : nextControl) : buttonFor(visibleItems[index]);
    }
    function recoverFocus(): void {
        if (activeFocus && (!focusedItem || visibleItems.indexOf(focusedItem) < 0 || visibleItems.indexOf(focusedItem) >= directCount)) {
            focusedItem = null;
            (overflow ? more : nextControl).forceActiveFocus(Qt.TabFocusReason);
        }
    }
    onActiveFocusChanged: { if (!activeFocus) focusedItem = null; }
    onVisibleItemsChanged: Qt.callLater(recoverFocus)
    onDirectCountChanged: Qt.callLater(recoverFocus)
    Row {
        anchors.fill: parent
        Repeater {
            id: buttons
            model: root.tray ? root.tray.items : null
            onItemRemoved: Qt.callLater(root.recoverFocus)
            TrayButton {
                id: button
                required property var modelData
                readonly property int position: root.visibleItems.indexOf(modelData)
                trayItem: modelData
                objectName: "tray-" + (modelData["id"] || modelData.objectName)
                visible: position >= 0 && position < root.directCount
                width: Metrics.trayButtonWidth; height: parent.height
                fillColor: hovered ? Theme.surface : Theme.background
                windowedTooltip: root.windowedTooltips
                leftTarget: root.adjacent(modelData, -1)
                rightTarget: root.adjacent(modelData, 1)
                KeyNavigation.backtab: leftTarget
                KeyNavigation.tab: rightTarget
                onActiveFocusChanged: {
                    if (activeFocus) root.focusedItem = modelData;

                }
                onPrimaryRequested: {
                    if (modelData.onlyMenu) root.menuRequested(modelData, button);
                    else root.activationRequested(modelData, false);
                }
                onSecondaryRequested: root.activationRequested(modelData, true)
                onMenuRequested: root.menuRequested(modelData, button)
                Keys.onEscapePressed: root.dismissed()
                background: Rectangle {
                    color: button.fillColor
                    UI.FocusIndicator {
                        control: button
                        anchors.margins: Metrics.focusWidth
                    }
                }
            }
        }
        UI.NavigationButton {
            id: more
            objectName: "trayOverflowButton"
            visible: root.overflow
            width: Metrics.trayButtonWidth; height: parent.height
            padding: 0
            text: "⋯"
            contentItem: UI.Glyph { section: "bar"; symbol: "more_horiz"; color: Theme.text }
            Accessible.name: qsTr("Więcej aplikacji w zasobniku: %1").arg(root.visibleItems.length)
            tooltip: Accessible.name
            windowedTooltip: root.windowedTooltips
            leftTarget: root.directCount > 0 ? root.buttonFor(root.visibleItems[root.directCount - 1]) : root.previousControl
            rightTarget: root.nextControl
            KeyNavigation.backtab: leftTarget
            KeyNavigation.tab: rightTarget
            onClicked: root.overflowRequested(more)
            Keys.onEscapePressed: root.dismissed()
        }
    }
}
