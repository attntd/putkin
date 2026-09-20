import QtQml

QtObject {
    id: root
    required property var service
    required property var coordinator
    required property var brightness
    readonly property Connections events: Connections {
        target: root.service
        function onResumed(): void { root.brightness.refresh(); }
        function onSucceeded(_action: string): void { root.coordinator.close(false); }
    }
}
