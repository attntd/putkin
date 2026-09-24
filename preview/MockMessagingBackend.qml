import QtQuick

MockSignalBackend {
    id: root
    property bool groupsEnabled: false
    property var groupOps: []
    property string groupResult: "succeeded"
    property var rows: []
    property var history: ({})
    property var storedDrafts: ({})
    property bool holdResponses: false
    property var held: []
    property int sentCount: 0
    property var replyDrafts: ({})
    property var operations: ({})
    property string replyResult: "sent"
    property string interactionError: ""
    property var directory: ({contacts: [
        {serviceId: "aci:peer", name: "Alicja", number: "+12025550101", profileName: "", blocked: false},
        {serviceId: "aci:other", name: "Łukasz", number: "+12025550102", profileName: "", blocked: false}
    ], groups: [{groupId: "group", name: "Projekt"}]})
    function seed(): void {
        calls = []; held = []; holdResponses = false; sentCount = 0;
        replyDrafts = ({}); operations = ({}); replyResult = "sent"; interactionError = "";
        accountState = "linked"; accountId = "account-a"; serviceState = "ready";
        configuration = ({enabled: true});
        capabilities = ["account.directory", "conversations.page", "conversation.get", "conversation.open", "messages.page", "message.get", "draft.get", "draft.set", "message.send", "recipient.resolve", "reply.draft.get", "reply.draft.set", "conversation.notifications", "operation.retry", "messages.read", "message.delete", "conversation.expiration"];
        groupOps = []; groupResult = "succeeded";
        if (groupsEnabled) capabilities = capabilities.concat(["group.create", "group.operations", "group.get", "group.update", "group.join", "group.quit", "group.reconcile", "directory.refresh", "directory.profile", "directory.avatar", "conversation.accept", "conversation.block", "conversation.preferences"]);
        rows = [
            {conversationId: "chat-a", title: "Alicja", searchText: "+12025550101", kind: "direct", target: "aci:peer", activityTimestampMs: 1790000000000, unreadCount: 180, canSend: true},
            {conversationId: "chat-g", title: "Projekt", searchText: "", kind: "group", target: "group", activityTimestampMs: 1780000000000, unreadCount: 1, canSend: true}
        ];
        history = ({"chat-a": [], "chat-g": []}); storedDrafts = ({});
        for (let i = 0; i < 180; i++) history["chat-a"].push(message("chat-a", "m-" + i, i));
        history["chat-g"].push(message("chat-g", "group-1", 0));
        generation += "s";
    }
    function message(cid: string, mid: string, index: int): var {
        return {conversationId: cid, messageId: mid, authorServiceId: "aci:peer", direction: "incoming", origin: "remote", status: "received", kind: "text", unread: true, sortTimestampMs: 1789900000000 + index * 600000,
            text: index % 7 === 0 ? "Zażółć gęślą jaźń 🐈 — Ελληνικά 日本語\n" + "Dłuższa wiadomość. ".repeat(12) : "Wiadomość " + index};
    }
    function complete(id: string, result: var, error: var): void {
        if (holdResponses) held.push({id: id, result: result, error: error});
        else Qt.callLater(() => root.response(id, result, error));
    }
    function release(): void { const values = held; held = []; holdResponses = false; for (const v of values) response(v.id, v.result, v.error); }
    function request(method: string, params: var): string {
        const id = "mock-msg-" + (++counter);
        calls = calls.concat([{method: method, params: Object.assign({}, params)}]);
        let result = null;
        let error = null;
        const cid = params.conversationId;
        if (params.accountId !== accountId) error = {code: "account_mismatch"};
        else if (method === "typing.set") result = {accepted: true};
        else if (method === "message.delete") {
            const message = (history[cid] || []).find(v => v.messageId === params.messageId);
            if (!message) error = {code: "not_found"};
            else {
                message.text = null; message.kind = "deleted"; message.attachments = []; message.canReply = false;
                result = {messageId: message.messageId, scope: params.scope};
                Qt.callLater(() => root.event("message.redacted", {accountId: root.accountId, conversationId: cid, messageId: message.messageId}));
            }
        }
        else if (method === "conversation.expiration") {
            const row = rows.find(v => v.conversationId === cid);
            row.expirationSeconds = params.seconds; result = row;
            Qt.callLater(() => root.event("conversation.changed", {accountId: root.accountId, conversationId: cid}));
        }
        else if (method === "message.edit" || method === "message.react") {
            const message = (history[cid] || []).find(v => v.messageId === params.messageId);
            if (interactionError) error = {code: interactionError};
            else if (!message) error = {code: "not_found"};
            else {
                if (method === "message.edit") { message.text = params.text; message.editedTimestampMs = message.versionTimestampMs + 1; message.versionTimestampMs++; }
                else message.reactions = params.remove ? [] : [{emoji: params.emoji, count: 1, mine: true, people: [{serviceId: "aci:self", name: "Ty"}]}];
                result = {operationId: params.operationId, state: "sent"};
                Qt.callLater(() => root.event("message.changed", {accountId: root.accountId, conversationId: cid, messageId: message.messageId}));
            }
        }
        else if (method === "account.directory" || method === "directory.refresh") result = directory;
        else if (method === "group.operations") result = {items: groupOps};
        else if (method === "group.get") result = directory.groups.find(g => g.groupId === params.groupId);
        else if (method === "directory.profile") result = directory.contacts.find(c => c.serviceId === params.serviceId);
        else if (method === "directory.avatar") result = {target: params.groupId || params.serviceId, avatar: ""};
        else if (method === "group.create" || method === "group.join") {
            result = {operationId: params.operationId, kind: method, state: groupResult, target: "group", conversationId: groupResult === "unknown" ? "" : "chat-g", candidates: [], errorCode: groupResult === "unknown" ? "result_unknown" : ""};
            groupOps = groupOps.concat([result]);
            Qt.callLater(() => root.event("directory.operation.changed", {accountId: root.accountId}));
        }
        else if (method === "group.reconcile") {
            result = groupOps.find(o => o.operationId === params.operationId);
            result.candidates = ["group"];
        }
        else if (method === "group.update" || method === "group.quit") {
            result = {operationId: params.operationId, state: "succeeded", conversationId: "chat-g", target: "group"};
            const group = directory.groups.find(g => g.groupId === params.groupId);
            if (params.action === "details") { group.name = params.name; group.description = params.description; }
            if (method === "group.quit") {
                group.isMember = false; group.membership = "left"; group.canSend = false; group.canAdmin = false; group.canEdit = false; group.canAdd = false; group.canLeave = false;
                const row = rows.find(r => r.conversationId === "chat-g"); row.canSend = false; row.canRead = false; row.requestState = "left";
            }
            Qt.callLater(() => root.event("account.directory.changed", {accountId: root.accountId}));
        }
        else if (method === "conversation.accept" || method === "conversation.block" || method === "conversation.preferences") {
            result = rows.find(r => r.conversationId === cid);
            if (method === "conversation.accept") { result.canRead = true; result.canSend = true; result.requestState = "accepted"; }
            else if (method === "conversation.block") { result.blocked = params.blocked; result.canSend = !params.blocked; result.canRead = !params.blocked; result.requestState = params.blocked ? "blocked" : "accepted"; }
            else result.hidden = params.hidden;
            Qt.callLater(() => root.event("conversation.changed", {accountId: root.accountId, conversationId: cid}));
        }
        else if (method === "conversations.page") result = {items: rows, nextCursor: null};
        else if (method === "conversation.get") {
            result = rows.find(v => v.conversationId === cid);
            if (!result) error = {code: "not_found"};
        } else if (method === "conversation.open" || method === "recipient.resolve") {
            if (method === "recipient.resolve" && params.query !== "+12025550102" && params.query !== "lukasz.42") error = {code: "recipient_unresolved"};
            else {
                let row = rows.find(v => v.conversationId === "chat-new");
                if (!row) { row = {conversationId: "chat-new", title: "Łukasz", searchText: "+12025550102", kind: "direct", target: "aci:other", activityTimestampMs: 1790100000000, unreadCount: 0, canSend: true}; rows = rows.concat([row]); history["chat-new"] = []; }
                result = row;
                Qt.callLater(() => root.event("conversation.changed", {accountId: root.accountId, conversationId: "chat-new"}));
            }
        } else if (method === "messages.page") {
            const values = history[cid] || [];
            const end = params.before === null ? values.length : Number(params.before);
            const start = Math.max(0, end - params.limit);
            result = {items: values.slice(start, end).reverse(), nextCursor: start ? String(start) : null};
        } else if (method === "messages.read") {
            const values = history[cid] || [];
            const end = params.throughMessageId ? values.findIndex(v => v.messageId === params.throughMessageId) : -1;
            const candidates = values.filter((v, i) => (params.throughMessageId ? i <= end : params.messageIds.includes(v.messageId))
                && v.direction === "incoming" && v.unread && ["text", "media"].includes(v.kind));
            const marked = candidates.slice(0, 100);
            marked.forEach(v => {
                v.unread = false;
                Qt.callLater(() => {
                    root.event("message.changed", {accountId: root.accountId, conversationId: cid, messageId: v.messageId});
                    root.event("message.read", {accountId: root.accountId, conversationId: cid, messageId: v.messageId});
                });
            });
            rows.find(v => v.conversationId === cid).unreadCount = values.filter(v => v.direction === "incoming" && v.unread).length;
            result = {messageIds: marked.map(v => v.messageId)};
            if (params.throughMessageId) result.hasMore = candidates.length > 100;
            Qt.callLater(() => root.event("conversation.changed", {accountId: root.accountId, conversationId: cid}));
        } else if (method === "message.get") {
            result = Object.values(history).reduce((all, items) => all.concat(items), []).find(v => v.messageId === params.messageId);
            if (!result) error = {code: "not_found"};
        } else if (method === "attachment.stage" || method === "attachment.paste" || method === "attachment.remove") {
            const draft = storedDrafts[cid] || {conversationId: cid, text: "", revision: 0, attachments: []};
            let attachments = draft.attachments || [];
            if (method === "attachment.remove") attachments = attachments.filter(a => a.attachment_id !== params.attachmentId);
            else attachments = attachments.concat((params.paths || ["Schowek.png"]).map((path, i) => ({attachment_id: id + "-" + i,
                filename: path.split("/").pop(), state: "ready", errorCode: "", size_bytes: 128, content_type: "image/png", thumbnail: "", preview: "", url: ""})));
            result = {attachments: attachments};
            storedDrafts[cid] = Object.assign({}, draft, result);
        } else if (method === "draft.get") result = storedDrafts[cid] || {conversationId: cid, text: "", revision: 0};
        else if (method === "draft.set") {
            const old = storedDrafts[cid] || {revision: 0};
            if (old.revision !== params.expectedRevision) error = {code: "draft_conflict"};
            else { result = {conversationId: cid, text: params.text, revision: old.revision + 1, composition: params.composition || {}, attachments: old.attachments || []}; storedDrafts[cid] = result; }
        } else if (method === "reply.draft.get") result = replyDrafts[cid] || {conversationId: cid, text: "", revision: 0, operationId: null, state: "", safeRetry: false};
        else if (method === "reply.draft.set") {
            const draft = replyDrafts[cid] || {revision: 0};
            if (draft.revision !== params.expectedRevision) error = {code: "draft_conflict"};
            else { result = {conversationId: cid, text: params.text, revision: draft.revision + 1, operationId: null, state: "", safeRetry: false}; replyDrafts[cid] = result; }
        } else if (method === "conversation.notifications") {
            result = rows.find(v => v.conversationId === cid);
            result.muted = params.muted;
            Qt.callLater(() => root.event("conversation.changed", {accountId: root.accountId, conversationId: cid}));
        } else if (method === "operation.retry") {
            const op = operations[params.operationId];
            if (!op || !op.safeRetry) error = {code: "retry_unsafe"};
            else { op.state = "sent"; op.safeRetry = false; result = op; settleReply(cid, "sent", false); }
        } else if (method === "message.send" && params.draftContext === "quickReply") {
            const draft = replyDrafts[cid];
            if (operations[params.operationId]) result = operations[params.operationId];
            else if (!draft || draft.revision !== params.draftRevision || draft.text !== params.text) error = {code: "draft_conflict"};
            else {
                sentCount++;
                result = {state: replyResult, operationId: params.operationId, messageId: "reply-" + sentCount, safeRetry: replyResult === "failed"};
                operations[params.operationId] = result;
                replyDrafts[cid] = {conversationId: cid, text: replyResult === "sent" ? "" : params.text, revision: draft.revision + 1,
                    operationId: params.operationId, state: replyResult, safeRetry: result.safeRetry};
                history[cid].push(Object.assign(message(cid, result.messageId, 900 + sentCount), {text: params.text, direction: "outgoing", origin: "local", status: replyResult}));
                Qt.callLater(() => root.event("operation.changed", {accountId: root.accountId, conversationId: cid, operationId: params.operationId}));
            }
        } else if (method === "message.send") {
            const draft = storedDrafts[cid];
            if (!draft || draft.revision !== params.draftRevision || draft.text !== params.text) error = {code: "draft_conflict"};
            else {
                sentCount++;
                const row = Object.assign(message(cid, "out-" + sentCount, 300 + sentCount), {text: params.text, status: "queued", direction: "outgoing", attachments: draft.attachments || []});
                history[cid].push(row);
                storedDrafts[cid] = {conversationId: cid, text: "", revision: draft.revision + 1};
                result = {state: "queued", operationId: params.operationId, messageId: row.messageId};
                Qt.callLater(() => root.event("message.changed", {accountId: root.accountId, conversationId: cid, messageId: row.messageId}));
            }
        } else error = {code: "unsupported_method"};
        complete(id, result || {}, error);
        return id;
    }
    function incoming(cid: string): void {
        const row = message(cid, "incoming-" + cid + "-" + history[cid].length, 400 + history[cid].length);
        history[cid].push(row);
        event("message.changed", {accountId: accountId, conversationId: cid, messageId: row.messageId});
        event("message.received", {accountId: accountId, conversationId: cid, messageId: row.messageId});
        event("conversation.changed", {accountId: accountId, conversationId: cid});
    }
    function settleReply(cid: string, state: string, safe: bool): void {
        const draft = replyDrafts[cid];
        replyDrafts[cid] = Object.assign({}, draft, {state: state, safeRetry: safe, text: state === "sent" ? "" : draft.text});
        Qt.callLater(() => root.event("operation.changed", {accountId: root.accountId, conversationId: cid, operationId: draft.operationId}));
    }
}
