pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var host
    property var levels: []
    property var renderedSession: null
    property var selectedItem: null
    property bool listHadFocus: false
    property int pendingFocusReason: Qt.TabFocusReason
    readonly property var session: host.coordinator.session
    readonly property var trayItem: session ? session.trayItem : null
    readonly property bool showingMenu: host.surfaceId === "trayMenu"
    readonly property var items: host.tray ? host.tray.items.values : []
    readonly property var currentLevel: levels.length ? levels[levels.length - 1] : null
    readonly property int depth: levels.length
    spacing: Metrics.space12
    signal requested(string surface)
    signal dismissed()
    signal ensureVisible(Item item)

    function clearLevels(): void {
        // Destroy deepest openers first; ancestor handles own their entries.
        for (let i = levels.length - 1; i >= 0; --i) levels[i].destroy();
        levels = [];
    }
    function reset(): void {
        if (renderedSession === session) return;
        renderedSession = session;
        pendingFocusReason = session ? session.focusReason : Qt.TabFocusReason;
        clearLevels();
        if (showingMenu && trayItem && trayItem.hasMenu && host.trayMenuComponent)
            push(trayItem.menu, trayItem.title || (trayItem["id"] || trayItem.objectName), pendingFocusReason);
        focusLater.restart();
    }
    function push(handle: var, title: string, reason: int): void {
        pendingFocusReason = reason;
        if (currentLevel) currentLevel.visible = false;
        const level = menuLevel.createObject(menuContainer, { handle: handle, title: title });
        levels = levels.concat([level]);
        focusLater.restart();
    }
    function back(reason = Qt.TabFocusReason): void {
        pendingFocusReason = reason;
        if (levels.length > 1) {
            const last = currentLevel;
            levels = levels.slice(0, -1);
            last.destroy();
            currentLevel.visible = true;
            focusLater.restart();
        } else if (showingMenu && session && session.returnToOverflow) {
            host.coordinator.open("trayOverflow", host.screen, null, reason);
        } else dismissed();
    }
    function dismissOrCollapse(): void { back(); }
    function focusInitial(reason = Qt.TabFocusReason): void {
        if (!enabled) return;
        pendingFocusReason = reason;
        if (currentLevel) currentLevel.focusInitial(reason);
        else moveSelection(-1, 1, reason);
    }
    function moveSelection(index: int, delta: int, reason = Qt.TabFocusReason): void {
        for (let i = index + delta; i >= 0 && i < items.length; i += delta) {
            const row = rows.itemAt(i) as TrayRow;
            if (row && row.visible) {
                row.action.forceActiveFocus(reason);
                return;
            }
        }
        backButton.forceActiveFocus(reason);
    }
    function validate(): void {
        if (showingMenu && (!trayItem || items.indexOf(trayItem) < 0 || !trayItem.hasMenu)) {
            host.coordinator.close(true);
            return;
        }
        // A parent can remove/disable the open submenu during a live update.
        for (let i = 1; i < levels.length; ++i) {
            if (!levels[i].handle || levels[i - 1].entries.indexOf(levels[i].handle) < 0
                    || !levels[i].handle.enabled || !levels[i].handle.hasChildren) {
                while (levels.length > i) back();
                break;
            }
        }
        if (!showingMenu && listHadFocus && (!selectedItem || items.indexOf(selectedItem) < 0 || selectedItem.status === 0))
            focusLater.restart();
    }
    onItemsChanged: validateLater.restart()
    onSessionChanged: resetLater.restart()
    Component.onCompleted: reset()
    function scheduleInitialFocus(): void { focusLater.restart(); }
    function scheduleValidation(): void { validateLater.restart(); }
    Timer { id: focusLater; interval: 0; onTriggered: root.focusInitial(root.pendingFocusReason) }
    Timer { id: resetLater; interval: 0; onTriggered: root.reset() }
    Timer { id: validateLater; interval: 0; onTriggered: root.validate() }
    Component.onDestruction: { focusLater.stop(); resetLater.stop(); validateLater.stop(); clearLevels(); }
    Connections {
        target: root.trayItem
        function onHasMenuChanged(): void { root.validate(); }
    }
    UI.PanelText {
        width: parent.width
        text: root.currentLevel ? root.currentLevel.title : qsTr("Aplikacje w zasobniku")
        font.bold: true
    }
    Row {
        width: parent.width; spacing: Metrics.space12
        UI.NavigationButton {
            id: backButton
            objectName: "trayBack"
            width: (parent.width - parent.spacing) / 2
            text: root.showingMenu ? qsTr("Wstecz") : qsTr("Do paska")
            rightTarget: closeButton
            KeyNavigation.tab: closeButton
            onClicked: root.back(focusReason)
            onActiveFocusChanged: {
                if (activeFocus) {
                    focusLater.stop();
                    root.listHadFocus = false;
                    if (root.currentLevel) root.currentLevel.hadFocus = false;
                }
            }
            onEnsureVisible: item => root.ensureVisible(item)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_J || event.key === Qt.Key_Down) { root.focusInitial(); event.accepted = true; }
                else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) { closeButton.forceActiveFocus(Qt.TabFocusReason); event.accepted = true; }
                else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) { root.back(); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!event.isAutoRepeat) click(); event.accepted = true; }
            }
        }
        UI.NavigationButton {
            id: closeButton
            objectName: "trayClose"
            width: backButton.width; text: qsTr("Zamknij")
            leftTarget: backButton
            KeyNavigation.backtab: backButton
            onClicked: root.dismissed()
            onActiveFocusChanged: {
                if (activeFocus) {
                    focusLater.stop();
                    root.listHadFocus = false;
                    if (root.currentLevel) root.currentLevel.hadFocus = false;
                }
            }
            onEnsureVisible: item => root.ensureVisible(item)
            Keys.onTabPressed: root.focusInitial()
            Keys.onDownPressed: root.focusInitial()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_J) { root.focusInitial(); event.accepted = true; }
                else if (event.key === Qt.Key_H) { backButton.forceActiveFocus(Qt.TabFocusReason); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!event.isAutoRepeat) click(); event.accepted = true; }
            }
        }
    }
    UI.PanelText {
        width: parent.width; color: Theme.textMuted
        visible: !root.showingMenu && root.items.length === 0
        text: qsTr("Brak aplikacji w zasobniku")
    }
    component TrayRow: Row { property Item action: null }
    Column {
        width: parent.width; spacing: Metrics.space4
        visible: !root.showingMenu
        Repeater {
            id: rows
            model: root.host.tray ? root.host.tray.items : null
            TrayRow {
                id: row
                required property var modelData
                required property int index
                action: action
                width: parent.width; spacing: Metrics.space4
                visible: modelData.status !== 0
                onVisibleChanged: { if (!visible && root.selectedItem === modelData) root.scheduleValidation(); }
                TrayButton {
                    id: action
                    trayItem: row.modelData
                    objectName: "trayApp-" + (row.modelData["id"] || row.modelData.objectName)
                    showLabel: true
                    width: row.width - menuButton.width - row.spacing
                    height: Metrics.controlHeight
                    rightTarget: menuButton.enabled ? menuButton : null
                    KeyNavigation.tab: menuButton.enabled ? menuButton : null
                    onPrimaryRequested: {
                        if (trayItem.onlyMenu) root.host.coordinator.openTray(trayItem, root.host.screen, null, focusReason);
                        else { trayItem.activate(); root.host.coordinator.close(false); }
                    }
                    onSecondaryRequested: { trayItem.secondaryActivate(); root.host.coordinator.close(false); }
                    onMenuRequested: root.host.coordinator.openTray(trayItem, root.host.screen, null, focusReason)
                    onActiveFocusChanged: { if (activeFocus) { root.selectedItem = trayItem; root.listHadFocus = true; } }
                    onEnsureVisible: item => root.ensureVisible(item)
                    Keys.onPressed: event => {
                        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
                        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) root.moveSelection(row.index, 1);
                        else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) root.moveSelection(row.index, -1);
                        else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) { if (menuButton.enabled) menuButton.forceActiveFocus(Qt.TabFocusReason); }
                        else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) backButton.forceActiveFocus(Qt.TabFocusReason);
                        else if (event.key === Qt.Key_Tab) { if (menuButton.enabled) menuButton.forceActiveFocus(Qt.TabFocusReason); else root.moveSelection(row.index, 1); }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!event.isAutoRepeat) click(); }
                        else return;
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: root.moveSelection(row.index, -1)
                }
                UI.NavigationButton {
                    id: menuButton
                    objectName: "trayAppMenu-" + (row.modelData["id"] || row.modelData.objectName)
                    width: Metrics.controlHeight; height: action.height
                    padding: 0; text: "›"
                    contentItem: UI.Glyph { symbol: "chevron_right"; color: menuButton.foreground }
                    tooltip: qsTr("Menu: %1").arg(action.text)
                    Accessible.name: tooltip
                    enabled: row.modelData.hasMenu
                    leftTarget: action
                    KeyNavigation.backtab: action
                    onClicked: root.host.coordinator.openTray(row.modelData, root.host.screen, null, focusReason)
                    onEnsureVisible: item => root.ensureVisible(item)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_J || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) root.moveSelection(row.index, 1);
                        else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) root.moveSelection(row.index, -1);
                        else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) action.forceActiveFocus(Qt.TabFocusReason);
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!event.isAutoRepeat) click(); }
                        else return;
                        event.accepted = true;
                    }
                }
            }
        }
    }
    Item {
        id: menuContainer
        width: parent.width
        implicitHeight: root.currentLevel ? root.currentLevel.implicitHeight : 0
        visible: root.showingMenu
    }
    Component {
        id: menuLevel
        TrayMenuLevel {
            menuComponent: root.host.trayMenuComponent
            backControl: backButton
            onDescend: (entry, reason) => root.push(entry, entry.text, reason)
            onActivated: entry => { entry.triggered(); root.host.coordinator.close(false); }
            onBackRequested: root.back()
            onEnsureVisible: item => root.ensureVisible(item)
            onEntriesUpdated: { root.validate(); if (visible && !focusedOnce) root.scheduleInitialFocus(); }
        }
    }
}
