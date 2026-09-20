import QtQuick
import "../../core"
import "../../components" as UI

Row {
    id: root
    required property var channel
    required property string monitor
    required property string prefix
    required property string title
    required property string symbol
    required property string mutedSymbol
    required property Item previousControl
    required property Item nextControl
    required property Item previousRow
    required property Item nextRow
    readonly property alias muteControl: mute
    readonly property alias volumeControl: volume
    signal ensureVisible(Item item)
    spacing: Metrics.space8

    function restoreVolume(): void { volume.value = Math.max(0, Math.min(100, channel.volume)); }
    UI.NavigationButton {
        id: mute
        objectName: root.prefix + "Mute"
        width: Metrics.controlHeight
        padding: 0
        enabled: root.channel.available
        text: root.title + (root.channel.muted ? qsTr(" · Włącz") : qsTr(" · Wycisz"))
        rightTarget: volume
        upTarget: root.previousRow
        downTarget: root.nextRow
        KeyNavigation.tab: volume
        KeyNavigation.backtab: root.previousControl
        onClicked: root.channel.toggleMute(root.monitor)
        onEnsureVisible: item => root.ensureVisible(item)
        contentItem: UI.Glyph {
            symbol: root.channel.muted ? root.mutedSymbol : root.symbol
            section: "slider"
            color: !mute.enabled ? Theme.textDisabled : Theme.text
        }
        background: Rectangle {
            color: mute.hovered ? Theme.surface : "transparent"
            UI.FocusIndicator { control: mute }
        }
    }
    UI.Slider {
        id: volume
        objectName: root.prefix + "Volume"
        width: Math.max(32, parent.width - mute.width - valueLabel.width - parent.spacing * 2)
        accessibleName: root.title
        from: 0; to: 100; stepSize: 5
        enabled: root.channel.available
        value: Math.max(0, Math.min(100, root.channel.volume))
        onMoved: { if (!root.channel.setVolume(value, root.monitor)) root.restoreVolume(); }
        onActiveFocusChanged: { if (activeFocus) root.ensureVisible(volume); }
        KeyNavigation.up: root.previousRow
        KeyNavigation.down: root.nextRow
        KeyNavigation.tab: root.nextControl
        KeyNavigation.backtab: mute
        Keys.onPressed: event => {
            if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
            if (event.key === Qt.Key_H || event.key === Qt.Key_L)
                root.channel.changeVolume(event.key === Qt.Key_H ? -stepSize : stepSize, root.monitor);
            else if (event.key === Qt.Key_J) root.nextRow.forceActiveFocus(Qt.TabFocusReason);
            else if (event.key === Qt.Key_K) root.previousRow.forceActiveFocus(Qt.TabFocusReason);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (!event.isAutoRepeat) root.channel.setVolume(value, root.monitor);
            } else return;
            event.accepted = true;
        }
    }
    UI.PanelText {
        id: valueLabel
        objectName: root.prefix + "Status"
        width: 44; height: Metrics.controlHeight
        horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
        text: root.channel.available ? Math.round(root.channel.volume) + "%" : "—"
    }
    Connections {
        target: root.channel
        function onVolumeChanged(): void { if (!root.channel.busy) root.restoreVolume(); }
        function onBusyChanged(): void { if (!root.channel.busy) root.restoreVolume(); }
    }
}
