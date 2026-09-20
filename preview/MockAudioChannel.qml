import QtQuick

QtObject {
    id: root
    property bool ready: true
    property var devices: [speakers, headphones]
    property var defaultDevice: speakers
    readonly property var snapshot: ready && defaultDevice ? {
        node: defaultDevice, volume: defaultDevice.volume, muted: defaultDevice.muted
    } : null
    property bool refreshing: false
    property bool rejectWrites: false
    property bool dropWrites: false
    property int delay: 0
    property var queued: null
    readonly property MockAudioNode speakers: MockAudioNode {}
    readonly property MockAudioNode headphones: MockAudioNode {
        name: "headphones"; description: "Słuchawki USB"; volume: 0.65
    }
    function writeVolume(node: var, value: real): bool { return write(node, "volume", value); }
    function writeMuted(node: var, value: bool): bool { return write(node, "muted", value); }
    function selectDevice(node: var): bool {
        if (rejectWrites) return false;
        if (!dropWrites) defaultDevice = node;
        return true;
    }
    function write(node: var, field: string, value: var): bool {
        if (rejectWrites) return false;
        if (dropWrites) return true;
        if (!delay) node[field] = value;
        else {
            const request = queued && queued.node === node ? Object.assign({}, queued) : { node: node };
            request[field] = value;
            queued = request;
            refreshing = true;
            delivery.restart();
        }
        return true;
    }
    readonly property Timer delivery: Timer {
        interval: root.delay
        onTriggered: {
            const request = root.queued;
            root.queued = null;
            if (root.ready && root.devices.indexOf(request.node) >= 0) {
                if (request.volume !== undefined) request.node.volume = request.volume;
                if (request.muted !== undefined) request.node.muted = request.muted;
            }
            root.refreshing = false;
        }
    }
    function resetChannel(): void {
        delivery.stop(); queued = null; refreshing = false;
        ready = true; rejectWrites = false; dropWrites = false; delay = 0;
        speakers.volume = 0.42; speakers.muted = false;
        headphones.volume = 0.65; headphones.muted = false;
        devices = [speakers, headphones]; defaultDevice = speakers;
    }
}
