import QtQuick

MockAudioChannel {
    id: root
    property alias outputs: root.devices
    property alias defaultOutput: root.defaultDevice
    readonly property MockAudioChannel input: MockAudioChannel {
        speakers.name: "microphone"
        speakers.description: "Mikrofon wbudowany"
        headphones.name: "usb-microphone"
        headphones.description: "Mikrofon USB"
        ready: root.ready
    }
    function reset(): void {
        resetChannel();
        input.resetChannel();
        input.ready = Qt.binding(() => root.ready);
    }
}
