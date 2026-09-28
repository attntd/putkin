import QtQml

QtObject {
    id: root
    required property var service
    required property var coordinator
    required property var brightness
    property var clock: null
    property var idle: null
    readonly property Connections events: Connections {
        target: root.service
        function onResumed(): void {
            if (root.clock) root.clock.refresh();
            if (root.idle) root.idle.resume();
            root.brightness.refresh();
        }
        function onSucceeded(_action: string): void { root.coordinator.close(false); }
    }
}
