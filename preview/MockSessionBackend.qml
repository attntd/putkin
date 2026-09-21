import QtQuick

QtObject {
    id: root
    property bool ready: true
    property string errorText: ""
    property bool automatic: true
    property var calls: []
    property var operation: null
    property int refreshCount: 0
    property var capabilities: ({ lock: { available: true, reason: "" }, logout: { available: true, reason: "" },
        reboot: { available: true, reason: "" }, poweroff: { available: true, reason: "" }, suspend: { available: true, reason: "" },
        hibernate: { available: true, reason: "" } })
    signal completed(int requestId, bool success, string message)
    signal progress(int requestId, string phase)
    signal resumed()
    function refresh(): void { refreshCount++; }
    function request(id: int, action: string): bool {
        operation = { id: id, action: action };
        calls = calls.concat([action === "suspend" || action === "hibernate" || action === "lock" ? "lock-requested" : action]);
        if (automatic) Qt.callLater(() => {
            if (!operation || operation.id !== id) return;
            if (action === "lock" || action === "suspend" || action === "hibernate") confirmLock();
            else settle(true, "Żądanie przyjęte (atrapa).");
        });
        return true;
    }
    function confirmLock(): void {
        if (!operation) return;
        calls = calls.concat(["lock-confirmed"]);
        progress(operation.id, "locked");
        if (operation.action === "suspend" || operation.action === "hibernate") calls = calls.concat([operation.action]);
        settle(true, "Żądanie przyjęte (atrapa).");
    }
    function settle(success: bool, message: string): void {
        if (!operation) return;
        const id = operation.id;
        operation = null;
        completed(id, success, message);
    }
    function cancel(id: int): void { if (operation && operation.id === id) operation = null; }
    function reset(): void { calls = []; operation = null; ready = true; automatic = true; errorText = ""; }
}
