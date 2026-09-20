import QtQuick

QtObject {
    id: root
    required property var backend
    property int actionTimeout: 22000
    property int sequence: 0
    property var pending: null
    property string lastError: ""
    property string resultText: ""
    property string phase: ""
    readonly property bool busy: pending !== null
    readonly property var capabilities: backend.capabilities
    signal succeeded(string action)
    signal resumed()

    function capability(action: string): var {
        return backend.ready && capabilities[action] ? capabilities[action]
            : { available: false, reason: backend.errorText || qsTr("Sprawdzanie możliwości sesji…") };
    }
    function request(action: string): bool {
        if (busy) return false;
        const value = capability(action);
        if (!value.available) { lastError = value.reason; return false; }
        const id = ++sequence;
        lastError = "";
        resultText = "";
        phase = ["lock", "suspend", "idleSuspend"].indexOf(action) >= 0 ? "locking" : "dispatching";
        pending = { id: id, action: action };
        deadline.restart();
        if (!backend.request(id, action)) {
            finish(id, false, qsTr("Adapter odrzucił żądanie sesji."));
            return false;
        }
        return true;
    }
    function refresh(): void { backend.refresh(); }
    function finish(id: int, success: bool, message: string): void {
        if (!pending || pending.id !== id) return;
        const action = pending.action;
        deadline.stop();
        pending = null;
        phase = "";
        if (success) { resultText = message; succeeded(action); }
        else lastError = message;
    }
    readonly property Timer deadline: Timer {
        interval: root.actionTimeout
        onTriggered: {
            const id = root.pending.id;
            root.finish(id, false, qsTr("Przekroczono czas oczekiwania. Wynik operacji jest nieznany; nie ponowiono żądania."));
            root.backend.cancel(id);
        }
    }
    readonly property Connections events: Connections {
        target: root.backend
        function onCompleted(id: int, success: bool, message: string): void { root.finish(id, success, message); }
        function onProgress(id: int, phase: string): void { if (root.pending && root.pending.id === id) root.phase = phase; }
        function onResumed(): void { root.resumed(); }
        function onReadyChanged(): void {
            if (!root.backend.ready && root.pending) root.finish(root.pending.id, false, root.backend.errorText || qsTr("Utracono adapter sesji."));
        }
    }
}
