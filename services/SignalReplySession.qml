import QtQuick

// One conversation draft shared by every toast/center view. Views own no send state.
QtObject {
    id: root
    required property var owner
    required property var route
    readonly property var service: owner.service
    property string text: ""
    property real revision: 0
    property string operationId: ""
    property string state: ""
    property bool safeRetry: false
    property bool ready: false
    property bool dirty: false
    property bool sendRequested: false
    property string pending: ""
    property string pendingKind: ""
    property string savedText: ""
    property bool refreshNeeded: false
    property bool uncertain: false
    property bool editing: false
    property bool typingSent: false
    property real lastTyping: 0
    readonly property bool typingEnabled: active && service.configuration.typingIndicators === true
    function stopTyping(): void {
        if (typingSent) service.backend.request("typing.set", {accountId: route.accountId, conversationId: route.conversationId, active: false});
        typingSent = false; lastTyping = 0;
    }
    function typingActivity(): void {
        if (!editing || !typingEnabled || !text.length) { stopTyping(); return; }
        if (Date.now() - lastTyping < 2000) return;
        typingSent = true; lastTyping = Date.now();
        service.backend.request("typing.set", {accountId: route.accountId, conversationId: route.conversationId, active: true});
    }
    onEditingChanged: { if (!editing) stopTyping(); }
    onTypingEnabledChanged: { if (!typingEnabled) stopTyping(); }
    Component.onDestruction: stopTyping()
    property string errorText: ""
    readonly property bool active: owner.available && owner.canReply(route)
    readonly property bool busy: sendRequested || ["queued", "sending"].indexOf(state) >= 0 || pendingKind === "send" || pendingKind === "retry"
    readonly property bool editable: active && ready && !busy && !uncertain && !(pendingKind === "load" && operationId)
        && (!operationId || state === "sent" || state === "cancelled")
    readonly property bool canSend: editable && text.trim().length > 0
    readonly property bool canRetry: active && ready && !pending && state === "failed" && safeRetry && !uncertain
    readonly property string statusText: errorText || ({queued: qsTr("W kolejce"), sending: qsTr("Wysyłanie"), sent: qsTr("Wysłano"),
        failed: qsTr("Błąd wysyłania"), unknown: qsTr("Wynik nieznany"), cancelled: qsTr("Anulowano")})[state] || ""
    function request(method: string, params: var, kind: string): bool {
        if (pending || route.accountId !== service.accountId) return false;
        params.accountId = route.accountId; params.conversationId = route.conversationId;
        pendingKind = kind;
        pending = service.backend.request(method, params);
        if (!pending) { pendingKind = ""; errorText = service.describeError("not_ready"); return false; }
        return true;
    }
    function load(): void {
        if (pending) { refreshNeeded = true; return; }
        if (!active) return;
        if (dirty) { flush(); return; }
        request("reply.draft.get", {}, "load");
    }
    function edit(value: string): void {
        if (!editable || value === text) return;
        text = value; dirty = true; errorText = "";
        typingActivity();
        flush();
    }
    function flush(): void {
        if (pending || !dirty || !ready || !active || uncertain) return;
        savedText = text;
        request("reply.draft.set", {text: text, expectedRevision: revision}, "save");
    }
    function send(): bool {
        if (!canSend) return false;
        stopTyping();
        sendRequested = true; errorText = "";
        flush(); finishSend();
        return true;
    }
    function finishSend(): void {
        if (!sendRequested || dirty || pending) return;
        if (!active) { sendRequested = false; return; }
        operationId = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const n = Math.floor(Math.random() * 16); return (c === "x" ? n : (n & 3) | 8).toString(16);
        });
        if (!request("message.send", {text: text, draftContext: "quickReply", draftRevision: revision, operationId: operationId}, "send")) {
            operationId = ""; sendRequested = false;
        }
    }
    function retry(): bool {
        if (!canRetry) return false;
        return request("operation.retry", {operationId: operationId}, "retry");
    }
    function receive(id: string, result: var, error: var): void {
        if (id !== pending) return;
        const kind = pendingKind;
        pending = ""; pendingKind = "";
        if (error) {
            sendRequested = false;
            // A transport failure may follow COMMIT. Re-read the durable draft;
            // never repeat message.send as a recovery action.
            uncertain = true;
            if (kind === "send" || kind === "retry") state = "unknown";
            errorText = error.code === "draft_conflict" ? qsTr("Szkic zmienił się w innym widoku.") : service.describeError(error.code);
            if (kind === "send" || kind === "retry") { dirty = false; Qt.callLater(load); }
            return;
        }
        if (kind === "save") {
            revision = result.revision; dirty = text !== savedText;
            operationId = result.operationId || ""; state = result.state || "";
            flush(); finishSend();
        } else if (kind === "load") {
            if (!dirty) text = result.text;
            revision = result.revision; operationId = result.operationId || "";
            state = result.state; safeRetry = result.safeRetry;
            ready = true; uncertain = false; errorText = "";
            flush(); finishSend();
        } else {
            sendRequested = false;
            state = result.state; operationId = result.operationId;
            load();
        }
        if (refreshNeeded && !pending) { refreshNeeded = false; Qt.callLater(load); }
    }
    function reset(): void {
        stopTyping();
        pending = ""; pendingKind = ""; sendRequested = false; ready = false;
        // Dirty text is kept in memory on a bridge reconnect, but cannot be sent
        // until a fresh revision is known. A whole shell reload uses SQLite.
        if (dirty) { uncertain = true; errorText = qsTr("Nie potwierdzono zapisu szkicu."); }
        else { text = ""; operationId = ""; state = ""; Qt.callLater(load); }
    }
    onActiveChanged: { if (active) load(); else editing = false; }
    readonly property Connections events: Connections {
        target: root.service
        function onResponse(id: string, result: var, error: var): void { root.receive(id, result, error); }
        function onReset(): void { root.reset(); }
        function onChanged(name: string, data: var): void {
            if (data.accountId !== root.route.accountId || data.conversationId !== root.route.conversationId) return;
            if (name === "operation.changed" && data.operationId === root.operationId) root.load();
            if (name === "message.changed" && root.operationId) root.load();
        }
    }
    Component.onCompleted: { if (!pending) load(); }
}
