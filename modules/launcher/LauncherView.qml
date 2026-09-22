pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import "../../core"
import "../../core/Icons.js" as Icons
import "../../components" as UI

FocusScope {
    id: root
    required property var service
    property real maximumHeight: 520
    property Item previewControl: null
    property int selectedIndex: 0
    property string selectedKey: ""
    property bool destroying: false
    property bool updateQueued: false
    readonly property var firstControl: search
    readonly property var resultsControl: results
    readonly property bool navigating: results.activeFocus
    readonly property int count: service ? service.results.length : 0
    readonly property bool showHeading: service && service.historyView && !service.mode && !service.commandInput
    readonly property string emptyText: service && service.commandInput ? ""
        : service && !service.backend.ready && service.backend.lastError ? "Launcher niedostępny"
        : service && (!service.backend.ready || service.searching) ? "Wyszukiwanie…"
        : service && service.mode === "clipboard" && service.backend.clipboardError ? "Schowek niedostępny"
        : service && service.historyView ? "Brak ostatnich pozycji" : "Brak wyników"
    readonly property var displayedEntries: resultsFade.displayedValue ? resultsFade.displayedValue.entries : []
    readonly property real rowsHeight: {
        const heights = displayedEntries.map(entry => entry.kind === "clipboard" ? Metrics.launcherClipboardRowHeight : Metrics.launcherRowHeight);
        const requested = heights.slice(0, Metrics.launcherVisibleResults).reduce((sum, height) => sum + height, 0);
        // Mixed results must not expose extra compact rows after scrolling.
        const limited = heights.length ? Math.min(requested, Metrics.launcherVisibleResults * Math.min(...heights)) : Metrics.launcherRowHeight;
        return Math.max(0, Math.min(limited, maximumHeight - Metrics.space12 * 2 - Metrics.controlHeight
            - Metrics.space8 - (heading.visible ? heading.implicitHeight + Metrics.space12 : 0)));
    }
    implicitHeight: Math.max(Metrics.controlHeight + Metrics.space12 * 2,
        resultsFade.visible ? resultsFade.y + resultsFade.height : 0)
    signal dismissed()
    signal requested(string surface)
    signal ensureVisible(Item item)

    function label(mode: string): string {
        return ({application: "Aplikacje", file: "Pliki", clipboard: "Schowek", recent: "Ostatnie", command: "Komenda", workspaceCommand: "Workspace"})[mode] || "";
    }
    function focusInitial(reason = Qt.TabFocusReason): void { search.forceActiveFocus(reason); search.cursorPosition = search.text.length; }
    function focusResults(): void { results.focusReason = Qt.TabFocusReason; results.forceActiveFocus(Qt.TabFocusReason); }
    function dismissOrCollapse(): void {
        if (search.activeFocus && count > 0) focusResults();
        else dismissed();
    }
    function select(offset: int): void {
        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + offset));
        rememberSelection();
        reveal();
    }
    function rememberSelection(): void {
        const entry = service && service.results[selectedIndex];
        selectedKey = entry ? entry.kind + ":" + entry.id : "";
        if (service) service.previewEntry(entry);
    }
    function reconcile(): void {
        const index = service ? service.results.findIndex(entry => entry.kind + ":" + entry.id === selectedKey) : -1;
        selectedIndex = index >= 0 ? index : 0;
        rememberSelection();
        reveal();
    }
    function queueReconcile(): void {
        if (destroying || updateQueued) return;
        updateQueued = true;
        const owner = root;
        Qt.callLater(() => {
            if (!owner || owner.destroying !== false) return;
            owner.updateQueued = false;
            owner.reconcile();
        });
    }
    function reveal(): void {
        if (count > 0) results.positionViewAtIndex(selectedIndex, ListView.Contain);
    }
    function activate(): void {
        if (service && selectedIndex >= 0 && selectedIndex < count) service.activate(service.results[selectedIndex]);
    }
    function key(event: var): void {
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
        results.focusReason = Qt.TabFocusReason;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) activate();
        } else if (event.key === Qt.Key_Down || (navigating && event.key === Qt.Key_J)) select(1);
        else if (event.key === Qt.Key_Up || (navigating && event.key === Qt.Key_K)) select(-1);
        else if (DismissKeys.matches(event, root)) dismissOrCollapse();
        else if (navigating && event.key === Qt.Key_L && previewControl && previewControl.visible) previewControl.forceActiveFocus(Qt.TabFocusReason);
        else if (navigating && (event.key === Qt.Key_L || event.key === Qt.Key_Slash || event.key === Qt.Key_I)) focusInitial();
        else if (navigating && event.key === Qt.Key_H) {
            if (chip.visible) chip.forceActiveFocus(Qt.TabFocusReason); else focusInitial();
        } else if (navigating && event.key === Qt.Key_Home) { selectedIndex = 0; rememberSelection(); reveal(); }
        else if (navigating && event.key === Qt.Key_End) { selectedIndex = count - 1; rememberSelection(); reveal(); }
        else if (search.activeFocus && event.key === Qt.Key_Backspace && !search.text.length && service.chipMode) {
            service.removeFilter(true);
            search.cursorPosition = search.text.length;
        } else return;
        event.accepted = true;
    }
    Component.onCompleted: reconcile()
    Component.onDestruction: destroying = true
    Keys.onPressed: event => key(event)
    Connections {
        target: root.service
        function onTextChanged(): void { search.text = root.service.text; root.selectedKey = ""; root.selectedIndex = 0; }
        function onResultsChanged(): void { root.queueReconcile(); }
        function onActivated(): void { root.dismissed(); }
        function onFocusRequested(): void { root.focusInitial(); }
    }

    UI.AccentRectangle {
        width: root.width
        height: Metrics.controlHeight + Metrics.space12 * 2
        color: Theme.backgroundStrong
        border.color: Theme.accentBorder
        border.width: Metrics.borderWidth
        accentOutline: true
    }
    RowLayout {
        x: Metrics.space12
        y: Metrics.space12
        width: root.width - Metrics.space12 * 2
        height: Metrics.controlHeight
        spacing: Metrics.space12
        UI.Glyph { symbol: "search"; section: "launcher"; Layout.preferredWidth: slotSize; Layout.preferredHeight: slotSize }
        UI.NavigationButton {
            id: chip
            objectName: "launcherChip"
            visible: root.service && root.service.chipMode.length > 0
            text: root.label(root.service ? root.service.chipMode : "")
            trailingIcon: "close"
            iconSection: "launcher"
            verticalPadding: 2
            highlighted: true
            Accessible.name: root.label(root.service ? root.service.chipMode : "") + ", usuń filtr"
            Layout.maximumWidth: Math.max(80, root.width * 0.4)
            rightTarget: search
            downTarget: results
            onClicked: { root.service.removeFilter(false); root.focusInitial(focusReason); }
        }
        UI.TextField {
            id: search
            objectName: "launcherSearch"
            Layout.fillWidth: true
            Layout.minimumWidth: 40
            text: root.service ? root.service.text : ""
            placeholderText: root.service && root.service.commandInput ? "" : root.service && root.service.chipMode ? "Szukaj…" : "Szukaj aplikacji, plików, schowka…"
            Accessible.name: "Wyszukiwanie"
            KeyNavigation.tab: results
            KeyNavigation.backtab: chip.visible ? chip : results
            onTextEdited: root.service.edit(text)
            Keys.onPressed: event => root.key(event)
        }
    }
    UI.FadeSwap {
        id: resultsFade
        objectName: "launcherResultsFade"
        y: Metrics.space12 + Metrics.controlHeight
        width: root.width
        height: displayedValue ? Metrics.space8 + (heading.visible ? heading.implicitHeight + Metrics.space12 : 0)
            + root.rowsHeight + Metrics.space12 : 0
        clip: true
        value: ({entries: root.service ? root.service.results : [], heading: root.showHeading, empty: root.emptyText})
        requested: root.count > 0 || root.emptyText.length > 0
        onDisplayedValueChanged: Qt.callLater(root.reveal)
        UI.AccentRectangle {
            y: -resultsFade.y
            width: root.width
            height: resultsFade.y + resultsFade.height
            color: Theme.backgroundStrong
            border.color: Theme.accentBorder
            border.width: Metrics.borderWidth
            accentOutline: true
        }
        UI.PanelText {
            id: heading
            x: Metrics.space12
            y: Metrics.space12
            width: root.width - Metrics.space12 * 2
            objectName: "launcherHeading"
            visible: resultsFade.displayedValue !== null && resultsFade.displayedValue.heading
            text: "Ostatnie"
            color: Theme.textMuted
            font.pixelSize: Metrics.smallFontSize
        }
        ListView {
            id: results
            property int focusReason: Qt.TabFocusReason
            objectName: "launcherResults"
            x: Metrics.space12
            y: Metrics.space8 + (heading.visible ? heading.implicitHeight + Metrics.space12 : 0)
            width: root.width - Metrics.space12 * 2
            height: root.rowsHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.displayedEntries
            currentIndex: -1
            // ListView selects its first delegate after an empty model is
            // replaced. Selection and keyboard input belong to this scope.
            onCountChanged: currentIndex = -1
            keyNavigationEnabled: false
            activeFocusOnTab: true
            onActiveFocusChanged: { if (activeFocus) focusReason = Qt.TabFocusReason; }
            KeyNavigation.tab: root.previewControl && root.previewControl.visible ? root.previewControl : chip.visible ? chip : search
            KeyNavigation.backtab: search
            Keys.forwardTo: [resultsInput]
            UI.ControlInput { id: resultsInput; control: results }
            Keys.onPressed: event => root.key(event)
            onHeightChanged: root.queueReconcile()
            Controls.ScrollBar.vertical: UI.ScrollBar {
                id: resultScroll
                objectName: "launcherResultsScrollbar"
                onPressedChanged: { if (pressed) results.focusReason = Qt.MouseFocusReason; }
            }
            delegate: Controls.ItemDelegate {
                id: row
                required property var modelData
                required property int index
                readonly property bool clipboard: modelData.kind === "clipboard"
                readonly property bool command: modelData.kind === "configuredCommand" || modelData.kind === "workspaceCommand"
                width: results.width - (resultScroll.size < 1 ? resultScroll.width + Metrics.space4 : 0)
                height: clipboard ? Metrics.launcherClipboardRowHeight : Metrics.launcherRowHeight
                padding: Metrics.space8
                hoverEnabled: true
                focusPolicy: Qt.NoFocus
                enabled: resultsFade.current
                Accessible.name: modelData.title + ", " + root.label(modelData.kind)
                onPressedChanged: { if (pressed) results.focusReason = Qt.MouseFocusReason; }
                onClicked: { root.selectedIndex = index; root.rememberSelection(); root.activate(); }
                HoverHandler {
                    onPointChanged: {
                        if (!hovered) return;
                        results.focusReason = Qt.MouseFocusReason;
                        root.selectedIndex = row.index;
                        root.rememberSelection();
                    }
                }
                background: UI.AccentRectangle {
                    color: root.selectedIndex === row.index ? Theme.surface : row.hovered ? Theme.background : "transparent"
                    border.width: root.selectedIndex === row.index ? Metrics.borderWidth : 0
                    border.color: Theme.border
                    UI.FocusIndicator { control: results; shown: root.selectedIndex === row.index }
                }
                contentItem: RowLayout {
                    spacing: Metrics.space12
                    UI.Glyph {
                        objectName: "launcherApplicationIcon"
                        visible: !row.clipboard
                        section: "launcher"
                        Layout.preferredWidth: slotSize
                        Layout.preferredHeight: slotSize
                        symbol: Icons.launcher(row.modelData)
                    }
                    UI.PanelText {
                        objectName: "launcherRowTitle"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        textFormat: Text.PlainText
                        text: row.modelData.title
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                    }
                    UI.PanelText {
                        objectName: "launcherRowSubtitle"
                        visible: !row.clipboard && !row.command
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: row.availableWidth * 0.45
                        Layout.preferredWidth: implicitWidth
                        text: row.modelData.subtitle || root.label(row.modelData.kind)
                        textFormat: Text.PlainText
                        color: Theme.textMuted
                        font.pixelSize: Metrics.smallFontSize
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                    }
                }
            }
            UI.PanelText {
                objectName: "launcherEmptyState"
                anchors.fill: parent
                visible: root.displayedEntries.length === 0 && text.length > 0
                text: resultsFade.displayedValue ? resultsFade.displayedValue.empty : ""
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
