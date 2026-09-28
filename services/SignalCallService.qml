import QtQuick

QtObject {
    id: root
    required property var service
    property bool blocked: false
    property bool available: false
    property var current: null
    property var requests: ({})
    property string actionError: ""
    property int revision: 0
    readonly property bool active: current !== null && current.state !== "ENDED"
    readonly property bool incoming: current !== null && current.state === "RINGING_INCOMING"
    readonly property bool busy: Object.values(requests).some(value => value.method !== "call.status")
    readonly property string lastError: {
        if (!actionError) return "";
        if (actionError === "call_audio_unavailable") return qsTr("Dźwięk połączenia jest niedostępny.");
        if (actionError === "call_unavailable") return qsTr("Rozmowy głosowe są niedostępne.");
        if (actionError === "call_busy") return qsTr("Trwa już połączenie.");
        return qsTr("Nie udało się wykonać działania połączenia.");
    }
    signal ringing()
    function apply(data: var): void {
        if (!data || data.accountId !== service.accountId) return;
        const previous = current;
        available = data.available;
        current = data.call || null;
        if (current && current.errorCode) actionError = current.errorCode;
        if (incoming && (!previous || previous.callId !== current.callId || previous.state !== "RINGING_INCOMING")) ringing();
    }
    function request(method: string, params: var): bool {
        if (method !== "call.status" && busy) return false;
        if (method === "call.status" && Object.values(requests).some(value => value.method === method)) return false;
        if (blocked && ["call.start", "call.accept"].includes(method)) return false;
        if (method !== "call.status") actionError = "";
        const id = service.backend.request(method, Object.assign({accountId: service.accountId}, params));
        if (id) requests = Object.assign({}, requests, {[id]: {method: method, revision: revision}});
        return id !== "";
    }
    function start(conversationId: string): bool { return request("call.start", {conversationId: conversationId}); }
    function accept(): bool { return incoming && request("call.accept", {callId: current.callId}); }
    function reject(): bool { return incoming && request("call.reject", {callId: current.callId}); }
    function hangup(): bool { return active && current.callId !== "" && request("call.hangup", {callId: current.callId}); }
    function mute(): bool { return active && request("call.mute", {callId: current.callId, muted: !current.muted}); }
    function dismiss(): bool { return !active && request("call.dismiss", {}); }
    function refresh(): void {
        if (service.ready && service.capabilities.includes("call.status")) request("call.status", {});
    }
    function clear(): void { revision++; current = null; available = false; requests = ({}); actionError = ""; }
    readonly property Connections changes: Connections {
        target: root.service
        function onChanged(name: string, data: var): void {
            if (name === "call.changed") { root.revision++; root.apply(data); }
            else if (name === "service.changed") root.refresh();
        }
        function onReset(): void { root.clear(); }
        function onAccountIdChanged(): void { root.clear(); root.refresh(); }
        function onReadyChanged(): void { if (root.service.ready) root.refresh(); else { root.available = false; root.current = null; } }
        function onResponse(id: string, result: var, error: var): void {
            if (!root.requests[id]) return;
            const meta = root.requests[id];
            const method = meta.method;
            const next = Object.assign({}, root.requests); delete next[id]; root.requests = next;
            if (error) { if (method !== "call.status") root.actionError = error.code; }
            // Events are authoritative; responses can be older than a terminal event.
            else if (method === "call.status" && meta.revision === root.revision) root.apply(result);
        }
    }
    Component.onCompleted: refresh()
}
