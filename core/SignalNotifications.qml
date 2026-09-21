import QtQuick
import "../services"
import "ConversationRoute.js" as Route

QtObject {
    id: root
    required property var service
    required property var notifications
    required property var messagesController
    readonly property bool available: service.ready && service.accountState === "linked" && service.configuration.enabled && !notifications.locked
    property var records: ({})
    property var replies: ({})
    property var pending: ({})
    property var current: null
    property string requestId: ""
    property string phase: ""
    property int revision: 0
    property real burstStart: 0
    property int burstCount: 0
    property string lastError: ""
    function valid(ref: var): bool {
        return Route.valid(ref) && ref.serviceId === "signal" && ref.accountId === service.accountId;
    }
    function clearReplies(): void {
        Object.values(replies).forEach(reply => { reply.text = ""; reply.dirty = false; reply.editing = false; reply.destroy(); });
        replies = ({}); revision++;
    }
    function trim(): void {
        const keys = notifications.history.filter(row => row.messageReference).map(row => Route.key(row.messageReference));
        for (const key of Object.keys(replies)) {
            const reply = replies[key];
            if (!keys.includes(key) && !reply.pending && !reply.dirty && !reply.busy && !reply.editing) {
                reply.destroy(); delete replies[key];
            }
        }
        for (const key of Object.keys(records)) if (!keys.includes(key)) delete records[key];
        revision++;
    }
    function canOpen(ref: var): bool { return revision >= 0 && available && valid(ref) && !!records[Route.key(ref)]; }
    function canReply(ref: var): bool { return canOpen(ref) && records[Route.key(ref)].canSend; }
    function conversationMuted(ref: var): bool { return canOpen(ref) && records[Route.key(ref)].muted === true; }
    function session(ref: var): var { return valid(ref) ? replies[Route.key(ref)] || null : null; }
    function actions(ref: var): var {
        if (!canOpen(ref)) return [];
        const result = [{identifier: "open", text: qsTr("Otwórz")}];
        if (canReply(ref)) result.push({identifier: "reply", text: qsTr("Odpowiedz")});
        return result;
    }
    function invoke(ref: var, action: string): bool {
        if (!canOpen(ref)) return false;
        // Opening is resolved again by S04's conversation.get before selection.
        if (action === "open") return messagesController.openConversation(Route.copy(ref));
        if (action === "reply" && canReply(ref)) {
            const key = Route.key(ref);
            if (!replies[key]) {
                trim();
                if (Object.keys(replies).length >= notifications.historyLimit) return false;
                replies[key] = replyComponent.createObject(root, {owner: root, route: Route.copy(ref)});
                revision++;
            }
            replies[key].editing = true;
            if (!replies[key].ready && !replies[key].pending) replies[key].load();
            return true;
        }
        if (action === "mute") {
            return service.backend.request("conversation.notifications", {accountId: ref.accountId, conversationId: ref.conversationId,
                muted: !records[Route.key(ref)].muted}) !== "";
        }
        return false;
    }
    function queue(ref: var, arrival: bool): void {
        if (!valid(ref) || typeof ref.messageId !== "string" || !ref.messageId || ref.messageId.length > 256) return;
        const key = Route.key(ref), old = pending[key];
        if (old && old.arrival && !arrival) return;
        // At most the 100 most recent conversation cards; catch-up does not
        // allocate one QML object or IPC request per envelope.
        if (!old && Object.keys(pending).length >= notifications.historyLimit) delete pending[Object.keys(pending)[0]];
        pending[key] = {ref: Object.assign(Route.copy(ref), {messageId: ref.messageId}), arrival: arrival || !!(old && old.arrival)};
        if (!batch.running) batch.start();
    }
    function refresh(): void {
        notifications.history.forEach(row => { if (row.messageReference) queue(row.messageReference, false); });
    }
    function pump(): void {
        if (requestId || !service.accountId || service.capabilities.indexOf("message.get") < 0) return;
        const key = Object.keys(pending)[0];
        if (!key) return;
        current = pending[key]; delete pending[key]; phase = "message";
        requestId = service.backend.request("message.get", {accountId: current.ref.accountId, messageId: current.ref.messageId});
        if (!requestId) { current = null; }
    }
    function receive(id: string, result: var, error: var): void {
        if (id !== requestId || !current) return;
        requestId = "";
        if (!valid(current.ref)) { current = null; Qt.callLater(pump); return; }
        if (error) {
            if (error.code === "not_found") {
                delete records[Route.key(current.ref)]; revision++;
                notifications.invalidateMessage(current.ref);
            }
            current = null; Qt.callLater(pump); return;
        }
        if (phase === "message") {
            if (result.messageId !== current.ref.messageId || result.conversationId !== current.ref.conversationId || result.direction !== "incoming" || result.origin !== "remote") {
                current = null; Qt.callLater(pump); return;
            }
            if (["deleted", "expired"].includes(result.kind) || result.hiddenLocal) {
                notifications.forgetMessage(current.ref); current = null; Qt.callLater(pump); return;
            }
            current.message = result; phase = "conversation";
            requestId = service.backend.request("conversation.get", {accountId: current.ref.accountId, conversationId: current.ref.conversationId});
            if (!requestId) current = null;
            return;
        }
        const ref = current.ref, message = current.message;
        records[Route.key(ref)] = result; revision++;
        const hidden = {deleted: qsTr("Wiadomość usunięta"), expired: qsTr("Wiadomość wygasła"),
            expiring_unsupported: qsTr("Wiadomość znikająca"), view_once_unsupported: qsTr("Wiadomość jednorazowa"), edit_unsupported: qsTr("Wiadomość edytowana")};
        const arrival = current.arrival && message.unread !== false && !["deleted", "expired", "edit_unsupported"].includes(message.kind);
        if (Date.now() - burstStart >= 2000) { burstStart = Date.now(); burstCount = 0; }
        const toast = arrival && !result.muted && burstCount < 3;
        if (toast && !notifications.hasMessageToast(ref) && !notifications.locked && !notifications.dnd) burstCount++;
        let preview = message.text === null ? hidden[message.kind] || qsTr("Załącznik") : message.text;
        if ((message.reactions || []).length) preview += "\n" + message.reactions.map(r => r.emoji + " " + r.count).join(" · ");
        notifications.publishMessage(ref, result.title, preview,
            message.sortTimestampMs, arrival, toast, result.muted,
            ((message.attachments || []).find(a => a.state === "ready" && a.thumbnail) || {}).thumbnail || "");
        if (message.unread === false) notifications.markMessageRead(ref);
        current = null; Qt.callLater(pump);
    }
    function reset(): void {
        pending = ({}); current = null; requestId = ""; records = ({}); revision++;
        notifications.redactMessages();
        if (available) refresh();
    }
    onAvailableChanged: { if (available) { refresh(); pump(); } }
    readonly property Timer batch: Timer { interval: 120; onTriggered: root.pump() }
    readonly property Component replyComponent: Component { SignalReplySession {} }
    readonly property Connections changes: Connections {
        target: root.service
        function onResponse(id: string, result: var, error: var): void { root.receive(id, result, error); }
        function onReset(): void { root.reset(); }
        function onAccountIdChanged(): void { root.clearReplies(); root.reset(); }
        function onCapabilitiesChanged(): void { root.refresh(); root.pump(); }
        function onChanged(name: string, data: var): void {
            if (name === "account.directory.changed") root.refresh();
            if (name === "history.cleared") { root.clearReplies(); root.notifications.forgetMessages(); root.reset(); return; }
            if (data.accountId !== root.service.accountId) return;
            const ref = {serviceId: "signal", accountId: data.accountId, conversationId: data.conversationId, messageId: data.messageId};
            if (name === "message.redacted") {
                root.notifications.forgetMessage(ref);
                const key = Route.key(ref), queued = root.pending[key];
                if (queued && queued.ref.messageId === ref.messageId) delete root.pending[key];
                if (root.current && root.current.ref.messageId === ref.messageId && Route.equal(root.current.ref, ref)) {
                    root.current = null; root.requestId = ""; Qt.callLater(root.pump);
                }
                return;
            }
            if (name === "message.read") {
                root.notifications.markMessageRead(ref);
                const queued = root.pending[Route.key(ref)];
                if (queued && queued.ref.messageId === ref.messageId) queued.arrival = false;
                if (root.current && root.current.ref.messageId === ref.messageId && Route.equal(root.current.ref, ref)) {
                    root.current = null; root.requestId = "";
                    root.queue(ref, false); Qt.callLater(root.pump);
                }
            }
            if (name === "message.received") root.queue(ref, true);
            if (name === "message.changed" || name === "message.removed" || name === "conversation.changed") {
                root.notifications.history.forEach(row => {
                    const saved = row.messageReference;
                    if (saved && Route.equal(saved, ref) && (!data.messageId || data.messageId === saved.messageId)) root.queue(saved, false);
                });
            }
        }
    }
    readonly property Connections historyChanges: Connections {
        target: root.notifications
        function onHistoryChanged(): void { Qt.callLater(root.trim); }
    }
}
