pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var audio
    required property string monitor
    required property Item nextControl
    required property Item previousControl
    property bool expanded: false
    property Item focusedControl: null
    readonly property Item firstControl: volume.enabled ? volume : outputs.enabled ? outputs : nextControl
    readonly property Item lastControl: expanded && devices.count ? devices.itemAt(devices.count - 1) : firstControl
    readonly property Item belowRow: expanded && devices.count ? devices.itemAt(0) : nextControl
    signal ensureVisible(Item item)
    spacing: Metrics.space8

    function collapse(): bool {
        if (!expanded) return false;
        expanded = false;
        firstControl.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }
    function restoreVolume(): void { volume.value = Math.max(0, Math.min(100, audio.volume)); }
    function reveal(item: Item): void { focusedControl = item; ensureVisible(item); }
    function rowKey(event: var): void {
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
        if (event.key === Qt.Key_H || event.key === Qt.Key_L) {
            if (audio.available) audio.changeVolume(event.key === Qt.Key_H ? -volume.stepSize : volume.stepSize, monitor);
        } else if (event.key === Qt.Key_J) belowRow.forceActiveFocus(Qt.TabFocusReason);
        else if (event.key === Qt.Key_K) previousControl.forceActiveFocus(Qt.TabFocusReason);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_I) {
            if (!event.isAutoRepeat && outputs.enabled) expanded = !expanded;
        } else return;
        event.accepted = true;
    }
    function recoverUnavailableFocus(): void {
        const current = root.Window.window ? root.Window.window.activeFocusItem : null;
        if (current && current.enabled && current.visible && current.activeFocusOnTab) return;
        if (!audio.available && (focusedControl === volume || focusedControl === mute))
            (audio.outputs.length ? outputs : nextControl).forceActiveFocus(Qt.TabFocusReason);
    }
    onExpandedChanged: { if (expanded) Qt.callLater(() => root.ensureVisible(outputs)); }

    Item {
        id: audioRow
        objectName: "audioRow"
        width: parent.width
        height: Metrics.controlHeight
        UI.FocusIndicator { control: volume.activeFocus ? volume : outputs.activeFocus ? outputs : mute }
        Row {
        width: parent.width
        spacing: Metrics.space4
        UI.Button {
            id: mute
            objectName: "audioMute"
            width: Metrics.controlHeight
            padding: 0
            enabled: root.audio.available
            text: root.audio.muted ? qsTr("Włącz dźwięk") : qsTr("Wycisz")
            focusPolicy: Qt.ClickFocus
            KeyNavigation.up: root.previousControl
            KeyNavigation.down: root.belowRow
            KeyNavigation.tab: root.belowRow
            KeyNavigation.backtab: root.previousControl
            onClicked: root.audio.toggleMute(root.monitor)
            onActiveFocusChanged: { if (activeFocus) root.reveal(mute); }
            Keys.onPressed: event => root.rowKey(event)
            contentItem: UI.Glyph { section: "slider"; symbol: root.audio.muted ? "volume_off" : "volume_up"; color: mute.enabled ? Theme.text : Theme.textDisabled }
            background: Rectangle { color: mute.hovered ? Theme.surface : "transparent" }
        }
        UI.Slider {
            id: volume
            objectName: "audioVolume"
            width: Math.max(32, parent.width - mute.width - valueLabel.width - outputs.width - parent.spacing * 3)
            accessibleName: qsTr("Głośność wyjścia")
            from: 0; to: 100; stepSize: 5
            enabled: root.audio.available
            drawFocus: false
            value: Math.max(0, Math.min(100, root.audio.volume))
            onMoved: { if (!root.audio.setVolume(value, root.monitor)) root.restoreVolume(); }
            onActiveFocusChanged: { if (activeFocus) root.reveal(volume); }
            KeyNavigation.up: root.previousControl
            KeyNavigation.down: root.belowRow
            KeyNavigation.tab: root.belowRow
            KeyNavigation.backtab: root.previousControl
            Keys.onPressed: event => root.rowKey(event)
        }
        UI.PanelText {
            id: valueLabel
            objectName: "audioStatus"
            width: 40; height: Metrics.controlHeight
            horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
            text: root.audio.available ? Math.round(root.audio.volume) + "%" : "—"
        }
        UI.Button {
            id: outputs
            objectName: "audioOutputs"
            width: Metrics.controlHeight; padding: 0
            enabled: root.audio.outputs.length > 0
            text: qsTr("Wyjście audio")
            Accessible.description: root.audio.outputName
            focusPolicy: Qt.ClickFocus
            KeyNavigation.up: root.previousControl
            KeyNavigation.down: root.belowRow
            KeyNavigation.tab: root.belowRow
            KeyNavigation.backtab: root.previousControl
            onClicked: root.expanded = !root.expanded
            onActiveFocusChanged: { if (activeFocus) root.reveal(outputs); }
            Keys.onPressed: event => root.rowKey(event)
            contentItem: UI.Glyph { section: "slider"; symbol: root.expanded ? "expand_more" : "chevron_right"; color: outputs.enabled ? Theme.text : Theme.textDisabled }
            background: Rectangle { color: outputs.hovered ? Theme.surface : "transparent" }
        }
        }
    }
    UI.FadeColumn {
        width: parent.width
        shown: root.expanded
        spacing: Metrics.space4
        Repeater {
            id: devices
            model: root.audio.outputs
            UI.NavigationButton {
                id: device
                required property var modelData
                required property int index
                objectName: "audioOutput-" + modelData.name
                width: parent.width
                text: root.audio.label(modelData)
                trailingIcon: root.audio.defaultOutput === modelData ? "check" : ""
                tooltip: root.audio.label(modelData)
                highlighted: root.audio.defaultOutput === modelData
                upTarget: index > 0 ? devices.itemAt(index - 1) : root.firstControl
                downTarget: index + 1 < devices.count ? devices.itemAt(index + 1) : root.nextControl
                KeyNavigation.tab: downTarget
                KeyNavigation.backtab: upTarget
                onClicked: root.audio.selectOutput(modelData, root.monitor)
                onEnsureVisible: item => root.reveal(item)
            }
            onItemRemoved: (_index, item) => { if (item.activeFocus) root.nextControl.forceActiveFocus(Qt.TabFocusReason); }
        }
    }
    Connections {
        target: root.audio
        function onVolumeChanged(): void { if (!root.audio.busy) root.restoreVolume(); }
        function onBusyChanged(): void { if (!root.audio.busy) root.restoreVolume(); }
        function onAvailableChanged(): void {
            if (!root.audio.available && (root.focusedControl === volume || root.focusedControl === mute))
                Qt.callLater(root.recoverUnavailableFocus);
        }
    }
}
