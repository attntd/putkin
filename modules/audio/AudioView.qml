pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var audio
    required property string monitor
    property Item focusedControl: null
    readonly property var controls: [output.muteControl, output.volumeControl,
        input.muteControl, input.volumeControl].concat(outputs.buttons, inputs.buttons)
    spacing: Metrics.space12
    signal dismissed()
    signal requested(string surface)
    signal ensureVisible(Item item)

    function neighbor(item: Item, step: int): Item {
        const index = controls.indexOf(item);
        for (let i = 1; i <= controls.length; i++) {
            const candidate = controls[(index + step * i + controls.length * 2) % controls.length];
            if (candidate && candidate.enabled && candidate.visible) return candidate;
        }
        return root;
    }
    function focusInitial(reason = Qt.TabFocusReason): void {
        (output.volumeControl.enabled ? output.volumeControl : input.volumeControl.enabled
            ? input.volumeControl : neighbor(input.volumeControl, 1)).forceActiveFocus(reason);
    }
    function reveal(item: Item): void { focusedControl = item; ensureVisible(item); }
    function recoverFocus(): void {
        if (!enabled) return;
        if (!focusedControl || !focusedControl.enabled || controls.indexOf(focusedControl) < 0) focusInitial();
    }
    function dismissOrCollapse(): void { dismissed(); }
    onControlsChanged: Qt.callLater(recoverFocus)

    AudioLevel {
        id: output
        width: parent.width
        channel: root.audio; monitor: root.monitor
        prefix: "audio"; title: qsTr("Głośność głośnika")
        symbol: "volume_up"; mutedSymbol: "volume_off"
        previousControl: root.neighbor(muteControl, -1)
        nextControl: root.neighbor(volumeControl, 1)
        previousRow: previousControl
        nextRow: input.volumeControl.enabled ? input.volumeControl : root.neighbor(input.volumeControl, 1)
        onEnsureVisible: item => root.reveal(item)
    }
    AudioLevel {
        id: input
        width: parent.width
        channel: root.audio.microphone; monitor: root.monitor
        prefix: "microphone"; title: qsTr("Głośność mikrofonu")
        symbol: "mic"; mutedSymbol: "mic_off"
        previousControl: root.neighbor(muteControl, -1)
        nextControl: root.neighbor(volumeControl, 1)
        previousRow: output.volumeControl.enabled ? output.volumeControl : root.neighbor(output.muteControl, -1)
        nextRow: nextControl
        onEnsureVisible: item => root.reveal(item)
    }
    DeviceChoices { id: outputs; channel: root.audio; prefix: "audioOutput-"; title: qsTr("Wyjście") }
    DeviceChoices { id: inputs; channel: root.audio.microphone; prefix: "audioInput-"; title: qsTr("Wejście") }
    Connections { target: root.audio; function onAvailableChanged(): void { Qt.callLater(root.recoverFocus); } }
    Connections { target: root.audio.microphone; function onAvailableChanged(): void { Qt.callLater(root.recoverFocus); } }

    component DeviceChoices: Column {
        id: choices
        required property var channel
        required property string prefix
        required property string title
        property var buttons: []
        width: parent.width
        spacing: Metrics.space4
        function rebuild(): void {
            const items = [];
            for (let i = 0; i < devices.count; i++) {
                const item = devices.itemAt(i);
                if (item) items.push(item);
            }
            buttons = items;
        }
        UI.PanelText { width: parent.width; text: choices.title; color: Theme.textMuted; font.pixelSize: Metrics.smallFontSize }
        Repeater {
            id: devices
            model: choices.channel.devices
            onItemAdded: Qt.callLater(choices.rebuild)
            onItemRemoved: Qt.callLater(choices.rebuild)
            delegate: UI.NavigationButton {
                id: device
                required property var modelData
                width: parent.width
                objectName: choices.prefix + modelData.name
                text: choices.channel.label(modelData)
                checked: choices.channel.defaultDevice === modelData
                highlighted: checked
                upTarget: root.neighbor(device, -1)
                downTarget: root.neighbor(device, 1)
                KeyNavigation.tab: downTarget
                KeyNavigation.backtab: upTarget
                onClicked: choices.channel.selectDevice(modelData, root.monitor)
                onEnsureVisible: item => root.reveal(item)
            }
        }
        UI.PanelText {
            width: parent.width
            visible: devices.count === 0
            text: choices.channel.statusText
            color: Theme.textDisabled
        }
    }
}
