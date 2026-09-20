import QtQuick

AudioChannelService {
    id: root
    readonly property var outputs: devices
    readonly property var defaultOutput: defaultDevice
    readonly property string outputName: deviceName
    function selectOutput(node: var, monitor: string): bool { return selectDevice(node, monitor); }

    readonly property AudioChannelService microphone: AudioChannelService {
        backend: root.backend.input
        isInput: true
        operationTimeout: root.operationTimeout
    }
}
