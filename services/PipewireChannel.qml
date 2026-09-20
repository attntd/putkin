import QtQuick
import Quickshell.Services.Pipewire

QtObject {
    id: root
    property bool isInput: false
    readonly property bool ready: Pipewire.ready
    readonly property var devices: Pipewire.nodes.values.filter(node => node.isSink !== isInput && !node.isStream && node.audio !== null)
    readonly property var defaultDevice: isInput ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    property var snapshot: null
    property bool refreshing: false
    property var queuedVolume: null
    property var queuedMute: null

    // Only the default device needs live channel data. Names/type of other
    // nodes do not need tracking; the list preserves native object identity.
    readonly property PwObjectTracker tracker: PwObjectTracker { objects: [] }
    function reset(): void {
        verifyRead.stop();
        refreshing = false;
        queuedVolume = null;
        queuedMute = null;
        snapshot = null;
        tracker.objects = ready && defaultDevice ? [defaultDevice] : [];
        Qt.callLater(publish);
    }
    function publish(): void {
        if (!ready || !defaultDevice || !defaultDevice.ready || !defaultDevice.audio) return;
        if (queuedVolume !== null || queuedMute !== null) {
            flush();
            return;
        }
        if (refreshing) return;
        const audio = defaultDevice.audio;
        if (audio.channels.length === 0 || !isFinite(audio.volume)) return;
        snapshot = { node: defaultDevice, volume: audio.volume, muted: audio.muted };
    }
    function writeVolume(node: var, value: real): bool {
        if (!ready || node !== defaultDevice) return false;
        refreshing = true;
        queuedVolume = value;
        flush();
        return true;
    }
    function writeMuted(node: var, value: bool): bool {
        if (!ready || node !== defaultDevice) return false;
        refreshing = true;
        queuedMute = value;
        flush();
        return true;
    }
    function flush(): void {
        if (!defaultDevice || !defaultDevice.ready) return;
        if (queuedVolume !== null) {
            const value = queuedVolume;
            queuedVolume = null;
            defaultDevice.audio.volume = value;
        }
        if (queuedMute !== null) {
            const value = queuedMute;
            queuedMute = null;
            defaultDevice.audio.muted = value;
        }
        verifyRead.restart();
    }
    function selectDevice(node: var): bool {
        if (!ready || devices.indexOf(node) < 0) return false;
        if (isInput) Pipewire.preferredDefaultAudioSource = node;
        else Pipewire.preferredDefaultAudioSink = node;
        return true;
    }
    // 0.3.1 setters emit optimistic changes and have no error/ack signal.
    // Rebind once after the command burst to enumerate actual server Props.
    // This timer never runs in idle. No wpctl, polling, or cached success.
    readonly property Timer verifyRead: Timer {
        interval: 100
        onTriggered: {
            root.tracker.objects = [];
            Qt.callLater(() => {
                if (root.ready && root.defaultDevice)
                    root.tracker.objects = [root.defaultDevice];
            });
        }
    }
    readonly property Connections nodeChanges: Connections {
        target: root.defaultDevice
        function onReadyChanged(): void {
            if (root.defaultDevice && root.defaultDevice.ready) {
                if (root.queuedVolume === null && root.queuedMute === null)
                    root.refreshing = false;
                Qt.callLater(root.publish);
            }
        }
    }
    readonly property Connections audioChanges: Connections {
        target: root.defaultDevice ? root.defaultDevice.audio : null
        function onVolumesChanged(): void { Qt.callLater(root.publish); }
        function onMutedChanged(): void { Qt.callLater(root.publish); }
        function onChannelsChanged(): void { Qt.callLater(root.publish); }
    }
    onReadyChanged: reset()
    onDefaultDeviceChanged: reset()
    Component.onCompleted: reset()
}
