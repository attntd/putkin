import QtQuick
pragma ComponentBehavior: Bound
import "../core/ConversationRoute.js" as Route

QtObject {
    id: root
    required property var service
    readonly property string serviceId: "signal"
    readonly property string displayName: "Signal"
    readonly property string accountId: service.accountId
    readonly property string statusText: service.statusText
    readonly property bool available: service.accountState === "linked" && service.configuration.enabled
    readonly property bool canCreate: available && service.ready
    property var conversations: []
    property var contacts: []
    property var directory: ({contacts: [], groups: []})
    property var groupDetails: null
    property var profileDetails: null
    property var groupOperations: []
    property int directoryBusy: 0
    readonly property bool canManageGroups: service.capabilities.indexOf("group.create") >= 0 && canCreate
    readonly property bool createUncertain: groupOperations.some(v => v.kind === "group.create" && ["sending", "unknown"].includes(v.state))
    function directoryRequest(method: string, params: var, action: string): bool {
        const id = request(method, params, {kind: "directoryAction", action: action});
        if (id) directoryBusy++;
        return id !== "";
    }
    function refreshDirectory(): void { directoryRequest("directory.refresh", {}, "refresh"); }
    function loadOperations(): void { if (service.capabilities.indexOf("group.operations") >= 0) request("group.operations", {}, {kind: "groupOperations"}); }
    function inspectContact(sid: string): void {
        directoryRequest("directory.profile", {serviceId: sid}, "profile");
        directoryRequest("directory.avatar", {serviceId: sid}, "avatar");
    }
    function inspectGroup(): void {
        if (!selectedConversation || selectedConversation.kind !== "group") return;
        groupDetails = directory.groups.find(g => g.groupId === selectedConversation.target) || null;
        directoryRequest("group.get", {groupId: selectedConversation.target}, "group");
        directoryRequest("directory.avatar", {groupId: selectedConversation.target}, "avatar");
    }
    function createGroup(name: string, members: var, avatar: string): bool {
        if (!canManageGroups || directoryBusy || createUncertain) return false;
        return directoryRequest("group.create", {operationId: localId(), name: name, members: members, avatar: avatar}, "createGroup");
    }
    function joinGroup(uri: string): bool {
        if (!canManageGroups || directoryBusy) return false;
        return directoryRequest("group.join", {operationId: localId(), uri: uri}, "joinGroup");
    }
    function openGroup(gid: string): bool {
        if (!canCreate || resolving) return false;
        stopTyping(); flushDraft(); selection++; resolving = true;
        const id = request("conversation.open", {kind: "group", groupId: gid}, {kind: "create"});
        if (!id) resolving = false;
        return id !== "";
    }
    function groupAction(action: string, params: var): bool {
        if (!selectedConversation || selectedConversation.kind !== "group" || directoryBusy) return false;
        params = Object.assign({}, params, {groupId: selectedConversation.target, operationId: localId(), action: action});
        return directoryRequest(action === "quit" ? "group.quit" : "group.update", params, "groupChange");
    }
    function reconcileGroup(op: string, gid: string): void {
        const params = {operationId: op};
        if (gid) { params.groupId = gid; params.confirm = "use-existing-group"; }
        directoryRequest("group.reconcile", params, gid ? "createGroup" : "reconcile");
    }
    function acceptConversation(): void {
        if (selectedRoute) directoryRequest("conversation.accept", {conversationId: selectedRoute.conversationId}, "conversation");
    }
    function blockConversation(blocked: bool, confirmed: bool): void {
        if (selectedRoute) directoryRequest("conversation.block", {conversationId: selectedRoute.conversationId, blocked: blocked,
            confirm: confirmed ? selectedRoute.conversationId : ""}, "conversation");
    }
    function muteConversation(muted: bool): void {
        if (selectedRoute) request("conversation.notifications", {conversationId: selectedRoute.conversationId, muted: muted}, {kind: "preferences"});
    }
    function hideConversation(hidden: bool): void {
        if (selectedRoute) request("conversation.preferences", {conversationId: selectedRoute.conversationId, hidden: hidden}, {kind: "preferences"});
    }
    function personName(sid: string): string {
        const contact = directory.contacts.find(c => c.serviceId === sid);
        return contact ? contact.name || contact.profileName || contact.number || contact.username || sid : sid;
    }
    property var selectedRoute: null
    property var selectedConversation: null
    readonly property ListModel messages: ListModel { dynamicRoles: true }
    property var requests: ({})
    property int selection: 0
    property bool loading: false
    property bool resolving: false
    property var nextCursor: null
    property string draftText: ""
    property bool draftReady: false
    property var drafts: ({})
    property string lastError: ""
    property bool sending: false
    property var draftAttachments: []
    property var mediaRequests: ({})
    property int mediaBusy: 0
    readonly property bool canSend: available && selectedConversation !== null && selectedConversation.canSend && draftReady && !sending && mediaBusy === 0
    property var refreshIds: ({})
    property var redactedIds: ({})
    property string messageRequest: ""
    property bool listLoading: false
    property bool listDirty: false
    property var listBuild: []
    property var readRequests: ({})
    property var editingMessage: null
    property string editText: ""
    property bool editBusy: false
    property var quotedMessage: null
    property var composeMentions: []
    property var editMentions: []
    property var editStyles: []
    property string jumpMessageId: ""
    property var typingAuthors: []
    property bool editorActive: false
    property real lastTypingRequest: 0
    property bool typingSent: false
    readonly property string composerText: editingMessage ? editText : draftText
    readonly property bool composerBusy: editingMessage ? editBusy : sending
    readonly property bool typingEnabled: service.ready && service.configuration.typingIndicators === true
    readonly property var mentionMembers: {
        if (!selectedConversation || selectedConversation.kind !== "group") return [];
        const group = directory.groups.find(g => g.groupId === selectedConversation.target);
        return (group ? group.members || [] : []).map(member => {
            const contact = directory.contacts.find(c => c.serviceId === member.serviceId);
            return {serviceId: member.serviceId, name: contact ? contact.name || contact.profileName || contact.number || member.serviceId : member.serviceId};
        });
    }
    signal composerLoaded()
    signal jumpRequested(string messageId)
    function localId(): string {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const n = Math.floor(Math.random() * 16); return (c === "x" ? n : (n & 3) | 8).toString(16);
        });
    }
    function rowById(mid: string): var {
        for (let i = 0; i < messages.count; i++) if (messages.get(i).messageId === mid) return messages.get(i);
        return null;
    }
    function beginEdit(mid: string): bool {
        const row = rowById(mid);
        if (!row || !canSend || !row.canEdit || editingMessage) return false;
        flushDraft();
        editingMessage = {messageId: mid, versionTimestampMs: row.versionTimestampMs, conversationId: selectedRoute.conversationId};
        editText = row.text; editMentions = JSON.parse(row.mentionsJson); editStyles = JSON.parse(row.stylesJson);
        editBusy = false; composerLoaded(); return true;
    }
    function cancelEdit(): void {
        if (editBusy) return;
        editingMessage = null; editText = ""; editMentions = []; editStyles = []; composerLoaded();
    }
    function replyTo(mid: string): void {
        const row = rowById(mid);
        if (!row || !canSend || !row.canReply || editingMessage) return;
        quotedMessage = {messageId: mid, text: row.text, author: row.author}; saveComposition(); composerLoaded();
    }
    function cancelQuote(): void { quotedMessage = null; saveComposition(); }
    function composition(): var {
        const result = {};
        if (composeMentions.length) result.mentions = composeMentions;
        if (quotedMessage) result.quoteMessageId = quotedMessage.messageId;
        return result;
    }
    function saveComposition(): void {
        if (!selectedRoute || !draftReady) return;
        const draft = drafts[selectedRoute.conversationId];
        if (!draft) return;
        draft.composition = composition(); draft.dirty = true; flushDraft();
    }
    function restoreComposition(draft: var): void {
        const saved = draft.composition || {};
        composeMentions = saved.mentions || []; quotedMessage = null;
        if (saved.quoteMessageId) request("message.get", {messageId: saved.quoteMessageId}, {kind: "draftQuote"});
    }
    function adjustedRanges(oldText: string, value: string, ranges: var): var {
        let start = 0, end = oldText.length, newEnd = value.length;
        while (start < end && start < newEnd && oldText[start] === value[start]) start++;
        while (end > start && newEnd > start && oldText[end - 1] === value[newEnd - 1]) { end--; newEnd--; }
        const delta = value.length - oldText.length;
        return ranges.filter(m => m.start + m.length <= start || m.start >= end).map(m => Object.assign({}, m, {start: m.start >= end ? m.start + delta : m.start}));
    }
    function editComposer(value: string): void {
        if (editingMessage) {
            editMentions = adjustedRanges(editText, value, editMentions);
            editStyles = adjustedRanges(editText, value, editStyles); editText = value;
        } else {
            composeMentions = adjustedRanges(draftText, value, composeMentions); editDraft(value);
        }
        typingActivity();
    }
    function addMention(member: var, position: int): void {
        const old = composerText, label = "@" + member.name;
        const value = old.slice(0, position) + label + " " + old.slice(position);
        editComposer(value);
        const mention = {serviceId: member.serviceId, start: position, length: label.length};
        if (editingMessage) editMentions = editMentions.concat([mention]);
        else { composeMentions = composeMentions.concat([mention]); saveComposition(); }
        composerLoaded();
    }
    function react(mid: string, emoji: string, remove: bool): bool {
        const row = rowById(mid);
        if (!row || !canSend || !row.canReact) return false;
        return request("message.react", {conversationId: selectedRoute.conversationId, messageId: mid,
            versionTimestampMs: row.versionTimestampMs, emoji: emoji, remove: remove, operationId: localId()}, {kind: "reaction"}) !== "";
    }
    function sendComposer(): bool {
        stopTyping();
        if (!editingMessage) return send();
        if (editBusy || !editText.trim()) return false;
        const params = Object.assign({}, editingMessage, {text: editText, mentions: editMentions, styles: editStyles, operationId: localId()});
        editBusy = request("message.edit", params, {kind: "edit", mid: editingMessage.messageId}) !== "";
        return editBusy;
    }
    function jumpTo(mid: string): void {
        if (!mid) return;
        if (rowById(mid)) { jumpRequested(mid); return; }
        jumpMessageId = mid;
        request("message.get", {messageId: mid}, {kind: "jump"});
    }
    function typingActivity(): void {
        if (!editorActive || !typingEnabled || !selectedRoute || !composerText.length) { stopTyping(); return; }
        if (Date.now() - lastTypingRequest < 2000) return;
        lastTypingRequest = Date.now(); typingSent = true;
        request("typing.set", {conversationId: selectedRoute.conversationId, active: true}, {kind: "typing"});
    }
    function stopTyping(): void {
        if (typingSent && selectedRoute) request("typing.set", {conversationId: selectedRoute.conversationId, active: false}, {kind: "typing"});
        typingSent = false; lastTypingRequest = 0;
    }
    onCanSendChanged: { if (!canSend) stopTyping(); }
    onEditorActiveChanged: { if (!editorActive) stopTyping(); }
    onTypingEnabledChanged: { if (!typingEnabled) { stopTyping(); typingAuthors = []; } }

    signal conversationOpened(var route)
    signal historyChanging(bool reset)
    signal historyChanged(bool reset)
    signal draftLoaded()

    function address(cid: string): var { return {serviceId: serviceId, accountId: accountId, conversationId: cid}; }
    function errorText(code: string): string {
        switch (code) {
        case "busy": return qsTr("Inna operacja jest w toku.");
        case "invalid_avatar": return qsTr("Nieprawidłowy obraz avatara.");
        case "invalid_group_link": return qsTr("Nieprawidłowy link grupy.");
        case "group_unavailable": return qsTr("Grupa jest niedostępna.");
        case "member_unavailable": return qsTr("Skład grupy uległ zmianie.");
        case "last_admin": return qsTr("Wybierz nowego administratora.");
        case "permission_denied": return qsTr("Brak uprawnień do tej zmiany.");
        case "partial_result": return qsTr("Zmiana grupy nie dotarła do wszystkich osób.");
        case "confirmation_required": return qsTr("Ta operacja wymaga potwierdzenia.");
        case "delete_unavailable": return qsTr("Usunięcie u wszystkich jest już niedostępne.");
        case "edit_limit": return qsTr("Minął czas edycji lub osiągnięto limit zmian.");
        case "version_conflict": return qsTr("Wiadomość została już zmieniona. Otwórz edycję ponownie.");
        case "edit_unavailable": case "message_unavailable": return qsTr("Ta wiadomość nie może zostać zmieniona.");
        case "operation_pending": return qsTr("Poprzednia zmiana nie została jeszcze potwierdzona.");
        case "quote_unavailable": return qsTr("Cytowana wiadomość jest niedostępna.");
        case "invalid_mention": case "invalid_range": return qsTr("Wzmianka jest nieprawidłowa.");
        case "invalid_recipient": return qsTr("Nieprawidłowy numer lub nazwa użytkownika.");
        case "recipient_unresolved": return qsTr("Nie znaleziono odbiorcy.");
        case "not_found": return qsTr("Rozmowa jest niedostępna.");
        case "draft_conflict": return qsTr("Szkic zmienił się w innym widoku. Wpisany tekst został zachowany.");
        case "send_unavailable": case "retention_unsupported": case "retention_unverified": return qsTr("Wysyłanie w tej rozmowie jest niedostępne.");
        case "result_unknown": return qsTr("Nie można potwierdzić operacji. Sprawdź historię przed ponowieniem.");
        case "attachment_size": case "attachment_limit": return qsTr("Przekroczono limit załączników lub wybrano pusty plik.");
        case "attachment_unsafe": case "unsafe_path": return qsTr("Ten plik nie może zostać użyty.");
        case "attachment_mime": return qsTr("Typ pliku nie zgadza się z jego zawartością.");
        case "attachment_changed": return qsTr("Plik zmienił się podczas przygotowania.");
        case "attachment_unavailable": return qsTr("Plik jest niedostępny.");
        case "media_quota": case "media_disk_full": return qsTr("Brak miejsca na załączniki.");
        case "clipboard_unavailable": return qsTr("Obraz w schowku jest niedostępny.");
        default: return service.describeError(code);
        }
    }
    function request(method: string, params: var, context: var): string {
        params.accountId = accountId;
        const id = service.backend.request(method, params);
        if (id) requests[id] = Object.assign({account: accountId, selection: selection}, context);
        else lastError = errorText("not_ready");
        return id;
    }
    function refresh(): void {
        if (!accountId || service.capabilities.indexOf("conversations.page") < 0) return;
        request("account.directory", {}, {kind: "directory"});
        refreshList(); loadOperations();
    }
    function refreshList(): void {
        if (listLoading) { listDirty = true; return; }
        if (!accountId || service.capabilities.indexOf("conversations.page") < 0) return;
        listLoading = true; listBuild = [];
        if (!request("conversations.page", {before: null, limit: 100}, {kind: "list"})) listLoading = false;
    }
    function selectConversation(route: var): bool {
        if (!Route.valid(route) || route.serviceId !== serviceId || route.accountId !== accountId) return false;
        stopTyping(); flushDraft();
        editingMessage = null; editText = ""; editBusy = false; quotedMessage = null; composeMentions = []; typingAuthors = []; jumpMessageId = "";
        selection++;
        selectedRoute = null; selectedConversation = null; draftReady = false; draftText = ""; draftAttachments = [];
        historyChanging(true); messages.clear(); historyChanged(true);
        refreshIds = ({}); messageRequest = "";
        resolving = false;
        lastError = "";
        return request("conversation.get", {conversationId: route.conversationId}, {kind: "select", route: route}) !== "";
    }
    function activate(item: var): void {
        groupDetails = null; profileDetails = null;
        historyChanging(true);
        selectedRoute = address(item.conversationId);
        selectedConversation = item;
        messages.clear(); nextCursor = null; loading = false;
        draftText = ""; draftReady = false; sending = false;
        const cached = drafts[item.conversationId];
        if (cached) { draftText = cached.text; draftAttachments = cached.attachments || []; draftReady = true; restoreComposition(cached); sending = cached.sending || cached.sendRequested || false; draftLoaded(); }
        else request("draft.get", {conversationId: item.conversationId}, {kind: "draft", cid: item.conversationId});
        loadMore();
        historyChanged(true);
        conversationOpened(selectedRoute);
    }
    function createConversation(query: string, contact: var): bool {
        if (!canCreate || resolving) return false;
        stopTyping(); flushDraft(); selection++; lastError = ""; resolving = true;
        editingMessage = null; editText = ""; editBusy = false; quotedMessage = null; composeMentions = []; typingAuthors = []; jumpMessageId = "";
        const id = contact ? request("conversation.open", {kind: "direct", serviceId: contact.id}, {kind: "create"})
            : request("recipient.resolve", {query: query}, {kind: "resolve"});
        if (!id) resolving = false;
        return id !== "";
    }
    function loadMore(): void {
        if (!selectedRoute || loading || (messages.count && !nextCursor)) return;
        loading = true;
        if (!request("messages.page", {conversationId: selectedRoute.conversationId, before: nextCursor, limit: 50}, {kind: "page", first: messages.count === 0})) loading = false;
    }
    function normalized(item: var): var {
        const contact = directory.contacts.find(v => v.serviceId === item.authorServiceId);
        const label = {queued: qsTr("W kolejce"), sending: qsTr("Wysyłanie"), sent: qsTr("Wysłano"), delivered: qsTr("Dostarczono"), read: qsTr("Przeczytano"), viewed: qsTr("Wyświetlono"), failed: qsTr("Błąd wysyłania"), unknown: qsTr("Wynik nieznany"), cancelled: qsTr("Anulowano")};
        let status = label[item.status] || "";
        const receipts = item.receiptSummary;
        if (receipts && receipts.total > 1) {
            if (receipts.delivered) status += " · " + qsTr("Dostarczono %1/%2").arg(receipts.delivered).arg(receipts.total);
            if (receipts.read) status += " · " + qsTr("Przeczytano %1/%2").arg(receipts.read).arg(receipts.total);
            if (receipts.viewed) status += " · " + qsTr("Wyświetlono %1/%2").arg(receipts.viewed).arg(receipts.total);
        }
        const hidden = {deleted: qsTr("Wiadomość usunięta"), expired: qsTr("Wiadomość wygasła"), expiring_unsupported: qsTr("Wiadomość znikająca"), view_once_unsupported: qsTr("Wiadomość jednorazowa"), edit_unsupported: qsTr("Wiadomość edytowana")};
        const changes = {name: qsTr("Zmieniono nazwę grupy"), description: qsTr("Zmieniono opis grupy"), members: qsTr("Zmieniono skład grupy"), pendingMembers: qsTr("Zmieniono zaproszenia"), requestingMembers: qsTr("Zmieniono prośby o dołączenie"), membership: qsTr("Zmieniono członkostwo"), permissionAddMember: qsTr("Zmieniono uprawnienia dodawania"), permissionEditDetails: qsTr("Zmieniono uprawnienia edycji"), permissionSendMessage: qsTr("Zmieniono uprawnienia wysyłania")};
        return {messageId: item.messageId, system: item.kind === "system", authorServiceId: item.authorServiceId || "",
            receiptsJson: JSON.stringify(item.receipts || []), timestamp: item.sortTimestampMs,
            day: Qt.formatDate(new Date(item.sortTimestampMs), "yyyy-MM-dd"),
            time: Qt.formatTime(new Date(item.sortTimestampMs), "HH:mm"),
            text: item.kind === "system" ? (item.systemChanges || []).map(k => changes[k] || k).join(" · ") : item.text === null ? (hidden[item.kind] || qsTr("Załącznik")) : item.text,
            author: item.direction === "outgoing" ? qsTr("Ty") : contact ? (contact.name || contact.profileName || contact.number || item.authorServiceId) : item.authorServiceId,
            outgoing: item.direction === "outgoing", status: status, attachmentsJson: JSON.stringify(item.attachments || []),
            canDeleteLocal: item.canDeleteLocal === true, canDeleteRemote: item.canDeleteRemote === true,
            expirationSeconds: item.expirationSeconds || 0,
            canReact: item.canReact === true, canEdit: item.canEdit === true, canReply: item.canReply === true,
            versionTimestampMs: item.versionTimestampMs || item.sentTimestampMs || 0,
            edited: !!item.editedTimestampMs, reactionsJson: JSON.stringify(item.reactions || []), quoteJson: JSON.stringify(item.quote || null),
            mentionsJson: JSON.stringify(item.mentions || []), stylesJson: JSON.stringify(item.styles || []), versionsJson: JSON.stringify(item.versions || []),
            interactionJson: JSON.stringify(item.interaction || null),
            operationId: item.operationId || "", safeRetry: item.safeRetry === true,
            statusCode: item.status, unread: item.unread === true,
            readable: item.direction === "incoming" && ["text", "media"].includes(item.kind)};
    }
    function markVisible(route: var, ids: var): void {
        if (!Route.equal(route, selectedRoute) || !available || !selectedConversation || selectedConversation.canRead === false || service.capabilities.indexOf("messages.read") < 0) return;
        const mids = ids.filter(mid => !readRequests[mid]).slice(0, 100);
        if (!mids.length) return;
        const id = request("messages.read", {conversationId: route.conversationId, messageIds: mids}, {kind: "read", mids: mids});
        if (id) mids.forEach(mid => { readRequests[mid] = id; });
    }
    function merge(items: var, reset: bool): void {
        historyChanging(reset);
        for (const item of items) {
            if (item.hiddenLocal || redactedIds[item.messageId]) continue;
            if (item.quote && redactedIds[item.quote.messageId]) item.quote = null;
            const row = normalized(item);
            let old = -1;
            for (let i = 0; i < messages.count; i++) if (messages.get(i).messageId === row.messageId) { old = i; break; }
            if (old >= 0 && messages.get(old).timestamp === row.timestamp) { messages.set(old, row); continue; }
            if (old >= 0) messages.remove(old);
            let index = 0;
            while (index < messages.count && (messages.get(index).timestamp < row.timestamp
                || (messages.get(index).timestamp === row.timestamp && messages.get(index).messageId < row.messageId))) index++;
            messages.insert(index, row);
        }
        historyChanged(reset);
    }
    function editDraft(value: string): void {
        if (!draftReady || !selectedRoute) return;
        const draft = drafts[selectedRoute.conversationId];
        draft.text = value; draftText = value; draft.composition = composition();
        draft.dirty = true;
        flushDraft();
    }
    function flushDraft(): void {
        for (const cid of Object.keys(drafts)) {
            const draft = drafts[cid];
            if (!draft.dirty || draft.pending || draft.sending || draft.conflict) continue;
            draft.pending = request("draft.set", {conversationId: cid, text: draft.text, expectedRevision: draft.revision, composition: draft.composition || {}}, {kind: "save", cid: cid, text: draft.text, composition: JSON.stringify(draft.composition || {})});
        }
    }
    function send(): bool {
        if (!canSend || (!draftText.trim() && !draftAttachments.length)) return false;
        const draft = drafts[selectedRoute.conversationId];
        if (draft.conflict) return false;
        stopTyping();
        draft.quoteMessageId = quotedMessage ? quotedMessage.messageId : ""; draft.mentions = composeMentions;
        draft.sendRequested = true; sending = true;
        flushDraft(); finishDraft(selectedRoute.conversationId);
        return true;
    }
    function finishDraft(cid: string): void {
        const draft = drafts[cid];
        if (!draft || draft.pending || draft.dirty || !draft.sendRequested || draft.sending) return;
        draft.sendRequested = false; draft.sending = true;
        // One durable operation ID per user action; never retry an unknown result.
        const op = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const n = Math.floor(Math.random() * 16); return (c === "x" ? n : (n & 3) | 8).toString(16);
        });
        if (!request("message.send", {conversationId: cid, text: draft.text, attachmentIds: (draft.attachments || []).map(a => a.attachment_id), draftRevision: draft.revision, operationId: op,
            quoteMessageId: draft.quoteMessageId || "", mentions: draft.mentions || []}, {kind: "send", cid: cid, text: draft.text})) {
            draft.sending = false; sending = false;
        }
    }
    function drainMessages(): void {
        if (messageRequest || !selectedRoute) return;
        const mid = Object.keys(refreshIds)[0];
        if (!mid) return;
        messageRequest = request("message.get", {messageId: mid}, {kind: "message"});
        if (messageRequest) delete refreshIds[mid];
    }
    function receive(id: string, result: var, error: var): void {
        const context = requests[id]; delete requests[id];
        if (!context || context.account !== accountId) return;
        const current = context.selection === selection;
        if (context.kind === "groupOperations") { if (!error) groupOperations = result.items; return; }
        if (context.kind === "directoryAction") {
            directoryBusy = Math.max(0, directoryBusy - 1);
            if (error) { if (context.action !== "avatar") lastError = errorText(error.code); loadOperations(); return; }
            if (context.action === "refresh") { directory = result; refresh(); }
            else if (context.action === "profile" && current) profileDetails = result;
            else if (context.action === "group" && current) groupDetails = result;
            else if (context.action === "avatar") {
                if (profileDetails && profileDetails.serviceId === result.target) profileDetails = Object.assign({}, profileDetails, {avatar: result.avatar});
                if (groupDetails && groupDetails.groupId === result.target) groupDetails = Object.assign({}, groupDetails, {avatar: result.avatar});
            } else {
                loadOperations(); refresh();
                if (result.errorCode) lastError = errorText(result.errorCode);
                if (["createGroup", "joinGroup"].includes(context.action) && result.conversationId && result.state !== "unknown" && current) selectConversation(address(result.conversationId));
            }
            return;
        }
        if (context.kind === "typing") return;
        if (context.kind === "edit" || context.kind === "reaction") {
            if (context.kind === "edit" && current) {
                editBusy = false;
                if (!error) cancelEdit();
            }
            if (error) lastError = errorText(error.code);
            return;
        }
        if (context.kind === "media" || context.kind === "attachments" || context.kind === "openMedia" || context.kind === "saveMedia") {
            if (mediaRequests[id]) { delete mediaRequests[id]; mediaBusy = Object.keys(mediaRequests).length; }
            if (error) { if (error.code !== "cancelled") lastError = errorText(error.code); return; }
            if (context.kind === "openMedia") { Qt.openUrlExternally(result.url); return; }
            if (result.attachments && drafts[context.cid]) {
                drafts[context.cid].attachments = result.attachments;
                if (selectedRoute && selectedRoute.conversationId === context.cid) draftAttachments = result.attachments;
            }
            return;
        }
        if (context.kind === "read") {
            context.mids.forEach(mid => { if (readRequests[mid] === id) delete readRequests[mid]; });
            if (error) { lastError = errorText(error.code); return; }
            // This response follows COMMIT. Do not wait for another page to
            // suppress duplicate visibility requests for the same message.
            if (current) for (let i = 0; i < messages.count; i++) {
                if ((result.messageIds || []).includes(messages.get(i).messageId)) messages.setProperty(i, "unread", false);
            }
            return;
        }
        if (id === messageRequest) messageRequest = "";
        Qt.callLater(drainMessages);
        if (!current && ["select", "resolve", "create", "page", "message", "draft", "draftQuote", "jump"].indexOf(context.kind) >= 0) return;
        if (error) {
            lastError = errorText(error.code);
            if (context.kind === "list") listLoading = false;
            if (context.kind === "page" && current) loading = false;
            if (["create", "resolve"].indexOf(context.kind) >= 0 && current) resolving = false;
            if (context.cid && drafts[context.cid]) {
                const draft = drafts[context.cid]; draft.pending = ""; draft.sendRequested = false; draft.sending = false;
                draft.conflict = true;
                if (selectedRoute && selectedRoute.conversationId === context.cid) sending = false;
            }
            return;
        }
        if (context.kind === "directory") {
            directory = result;
            contacts = result.contacts.filter(v => v.serviceId && v.serviceId !== result.ownServiceId && !v.blocked && !v.unregistered).map(v => ({id: v.serviceId, title: v.name || v.profileName || v.number || v.username || v.serviceId, subtitle: [v.number, v.username].filter(Boolean).join(" · "), about: v.about || ""}));
            if (selectedConversation && selectedConversation.kind === "group") groupDetails = result.groups.find(g => g.groupId === selectedConversation.target) || null;
            for (let i = 0; i < messages.count; i++) {
                const row = messages.get(i);
                if (!row.outgoing && !row.system) messages.setProperty(i, "author", personName(row.authorServiceId));
            }
            refreshList();
        } else if (context.kind === "list") {
            listBuild = listBuild.concat(result.items.map(v => Object.assign({}, v, {route: address(v.conversationId), serviceName: displayName})));
            if (result.nextCursor) request("conversations.page", {before: result.nextCursor, limit: 100}, {kind: "list"});
            else {
                conversations = listBuild; listLoading = false;
                if (selectedRoute) selectedConversation = conversations.find(v => v.conversationId === selectedRoute.conversationId) || selectedConversation;
                if (listDirty) { listDirty = false; refreshList(); }
            }
        } else if (context.kind === "save") {
            const draft = drafts[context.cid];
            draft.pending = ""; draft.revision = Math.max(draft.revision, result.revision); draft.dirty = draft.text !== context.text || JSON.stringify(draft.composition || {}) !== context.composition;
            flushDraft(); finishDraft(context.cid);
        } else if (context.kind === "send") {
            const draft = drafts[context.cid];
            draft.attachments = []; draft.composition = {};
            draft.sending = false; draft.revision++;
            if (draft.text === context.text) draft.text = "";
            draft.dirty = draft.text !== "";
            if (selectedRoute && selectedRoute.conversationId === context.cid) { draftText = draft.text; draftAttachments = []; sending = false; quotedMessage = null; composeMentions = []; draftLoaded(); }
            flushDraft();
        } else if (!current) return;
        else if (context.kind === "select" || context.kind === "resolve") { resolving = false; activate(result); }
        else if (context.kind === "create") { resolving = false; selectConversation(address(result.conversationId)); }
        else if (context.kind === "page") {
            loading = false; nextCursor = result.nextCursor; merge(result.items, context.first);
            if (jumpMessageId) {
                if (rowById(jumpMessageId)) { const mid = jumpMessageId; jumpMessageId = ""; Qt.callLater(() => jumpRequested(mid)); }
                else if (nextCursor) loadMore();
                else jumpMessageId = "";
            }
        }
        else if (context.kind === "draftQuote" && selectedRoute && result.conversationId === selectedRoute.conversationId
                && (drafts[selectedRoute.conversationId].composition || {}).quoteMessageId === result.messageId) {
            if (redactedIds[result.messageId] || !result.canReply) return;
            quotedMessage = {messageId: result.messageId, text: result.text || qsTr("Wiadomość niedostępna"), author: normalized(result).author};
        }
        else if (context.kind === "message") merge([result], false);
        else if (context.kind === "jump" && result.conversationId === selectedRoute.conversationId) {
            // Load the contiguous older pages; inserting only the target would
            // introduce a hidden gap in pagination.
            if (rowById(result.messageId)) { jumpRequested(result.messageId); jumpMessageId = ""; }
            else loadMore();
        }
        else if (context.kind === "draft") {
            drafts[context.cid] = {text: result.text, composition: result.composition || {}, attachments: result.attachments || [], revision: result.revision, dirty: false, pending: "", sending: false, sendRequested: false, conflict: false};
            draftAttachments = result.attachments || [];
            draftText = result.text; draftReady = true; restoreComposition(drafts[context.cid]); draftLoaded();
        }
    }
    function clear(): void {
        stopTyping(); editingMessage = null; editText = ""; editBusy = false; quotedMessage = null; composeMentions = []; typingAuthors = []; jumpMessageId = "";
        draftAttachments = []; mediaRequests = ({}); mediaBusy = 0;
        redactedIds = ({}); groupDetails = null; profileDetails = null; groupOperations = []; directoryBusy = 0;
        selection++; requests = ({}); readRequests = ({}); drafts = ({}); conversations = []; contacts = [];
        selectedRoute = null; selectedConversation = null; messages.clear(); refreshIds = ({}); messageRequest = "";
        draftText = ""; draftReady = false; sending = false; loading = false; resolving = false; listLoading = false; listDirty = false;
        refresh();
    }
    onAccountIdChanged: clear()
    function attachFiles(paths: var): bool {
        return prepareMedia("attachment.stage", {paths: paths});
    }
    function pasteImage(): bool { return prepareMedia("attachment.paste", {}); }
    function prepareMedia(method: string, params: var): bool {
        if (!canSend || !selectedRoute) return false;
        params.conversationId = selectedRoute.conversationId;
        const id = request(method, params, {kind: "media", cid: selectedRoute.conversationId});
        if (id) { mediaRequests[id] = true; mediaBusy = Object.keys(mediaRequests).length; }
        return id !== "";
    }
    function cancelMedia(): void {
        Object.keys(mediaRequests).forEach(id => service.backend.request("request.cancel", {id: id}));
    }
    function removeAttachment(aid: string): void {
        prepareMedia("attachment.remove", {attachmentId: aid});
    }
    function saveAttachment(aid: string, destination: string): void {
        request("attachment.save", {attachmentId: aid, destination: destination}, {kind: "saveMedia"});
    }
    function openAttachment(aid: string): void {
        request("attachment.open", {attachmentId: aid}, {kind: "openMedia"});
    }
    function deleteMessage(mid: string, scope: string): bool {
        const row = rowById(mid);
        if (!row || !selectedRoute || (scope === "everyone" ? !row.canDeleteRemote : !row.canDeleteLocal)) return false;
        return request("message.delete", {conversationId: selectedRoute.conversationId, messageId: mid,
            scope: scope, versionTimestampMs: row.versionTimestampMs, operationId: localId()}, {kind: "delete"}) !== "";
    }
    function setExpiration(seconds: int): void {
        if (selectedRoute) request("conversation.expiration", {conversationId: selectedRoute.conversationId, seconds: seconds}, {kind: "expiration"});
    }
    function redactMessage(mid: string): void {
        redactedIds[mid] = true;
        if (editingMessage && editingMessage.messageId === mid) { editBusy = false; cancelEdit(); }
        if (quotedMessage && quotedMessage.messageId === mid) quotedMessage = null;
        for (const cid of Object.keys(drafts)) {
            const draft = drafts[cid];
            if ((draft.composition || {}).quoteMessageId === mid) delete draft.composition.quoteMessageId;
            if (draft.quoteMessageId === mid) draft.quoteMessageId = "";
        }
        historyChanging(false);
        for (let i = messages.count - 1; i >= 0; i--) {
            const row = messages.get(i);
            if (row.messageId === mid) messages.remove(i);
            else {
                const quote = JSON.parse(row.quoteJson);
                if (quote && quote.messageId === mid) messages.setProperty(i, "quoteJson", "null");
            }
        }
        historyChanged(false);
    }
    function changeOperation(op: string, retry: bool): void {
        request(retry ? "operation.retry" : "operation.cancel", {operationId: op}, {kind: "operation"});
    }
    readonly property Connections changes: Connections {
        target: root.service
        function onResponse(id: string, result: var, error: var): void { root.receive(id, result, error); }
        function onReset(): void { root.clear(); }
        function onCapabilitiesChanged(): void { root.refresh(); }
        function onChanged(name: string, data: var): void {
            if (name === "history.cleared") { root.clear(); return; }
            if (data.accountId !== root.accountId) return;
            if (name === "conversation.changed" || name === "message.changed" || name === "message.removed") root.refreshList();
            if (name === "account.directory.changed") root.refresh();
            if (name === "directory.operation.changed") root.loadOperations();
            if (name === "message.redacted") root.redactMessage(data.messageId);
            if (name === "draft.changed" && data.quoteRemoved && root.drafts[data.conversationId]) {
                const draft = root.drafts[data.conversationId];
                delete draft.composition.quoteMessageId; draft.quoteMessageId = "";
                draft.revision = Math.max(draft.revision, data.revision);
            }
            if (!root.selectedRoute || data.conversationId !== root.selectedRoute.conversationId) return;
            if (name === "typing.changed") root.typingAuthors = root.typingEnabled ? data.authors.map(sid => {
                const contact = root.directory.contacts.find(c => c.serviceId === sid);
                return contact ? contact.name || contact.profileName || contact.number || sid : sid;
            }) : [];
            if (name === "attachments.changed") root.request("draft.get", {conversationId: data.conversationId}, {kind: "attachments", cid: data.conversationId});
            if (name === "message.changed") { root.refreshIds[data.messageId] = true; root.drainMessages(); }
            if (name === "message.removed") {
                root.historyChanging(false);
                for (let i = 0; i < root.messages.count; i++) if (root.messages.get(i).messageId === data.messageId) { root.messages.remove(i); break; }
                root.historyChanged(false);
            }
        }
    }
    Component.onCompleted: refresh()
}
