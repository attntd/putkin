import QtQuick

QtObject {
    id: root
    required property var backend
    readonly property string state: backend.serviceState
    readonly property string accountState: backend.accountState
    readonly property string accountId: backend.accountId
    readonly property int schemaVersion: backend.schemaVersion
    readonly property bool ready: backend.ready
    readonly property string cliVersion: backend.cliVersion
    readonly property var capabilities: backend.capabilities
    readonly property string errorCode: backend.errorCode
    readonly property var configuration: backend.configuration
    readonly property string linkAttempt: backend.linkAttempt
    readonly property string linkError: backend.linkError
    readonly property bool reconciling: backend.reconciling
    readonly property bool canManageAccount: backend.generation !== "" && capabilities.indexOf("account.configure") >= 0
    property var qrModules: []
    property real qrExpiresAt: 0
    property string qrAttempt: ""
    property string actionError: ""
    property var accountRequests: ({})
    readonly property string errorText: describeError(errorCode)
    readonly property string lastError: describeError(actionError || errorCode)
    readonly property string statusText: {
        if (accountState === "linking" || linkAttempt) return qsTr("Parowanie");
        if (reconciling) return qsTr("Sprawdzanie powiązania");
        if (errorCode === "cli_unavailable") return qsTr("Brak signal-cli");
        if (state === "disabled") return qsTr("Odbiór wyłączony");
        if (accountState === "relinkRequired") return qsTr("Powiązanie niedostępne");
        if (accountState === "linked" && (state === "reconnecting" || state === "failed")
                && ["transport_lost", "timeout", "rpc_error", "result_unknown"].indexOf(errorCode) >= 0) return qsTr("Offline");
        if (state === "failed") return qsTr("Wymaga działania");
        if (accountState === "linked") return qsTr("Połączony");
        if (state === "starting") return qsTr("Łączenie");
        if (backend.linkError === "link_expired") return qsTr("Kod wygasł");
        return qsTr("Niepołączony");
    }
    function describeError(code: string): string {
        switch (code) {
        case "": return "";
        case "cancelled": return "";
        case "qr_unavailable": return qsTr("Brak biblioteki libqrencode.");
        case "link_expired": return qsTr("Kod parowania wygasł.");
        case "relink_required": return qsTr("Powiązanie urządzenia Signal jest niedostępne.");
        case "directory_sync_failed": return qsTr("Nie udało się zsynchronizować kontaktów i grup.");
        case "invalid_link": case "qr_error": return qsTr("Nie można wyświetlić kodu parowania.");
        case "confirmation_required": return qsTr("Usunięcie lokalnej historii wymaga potwierdzenia.");
        case "not_disabled": return qsTr("Przed usunięciem historii wyłącz odbiór.");
        case "busy": return qsTr("Usługa Signal jest już uruchomiona.");
        case "cli_unavailable": return qsTr("Nie znaleziono działającego signal-cli.");
        case "unsupported_version": return qsTr("Nieobsługiwana wersja protokołu lub signal-cli.");
        case "media_policy_required": return qsTr("signal-cli wymaga przygotowanej wersji z obsługą mediów Putkina.");
        case "runtime_invalid": return qsTr("Pakiet Signala jest niekompletny lub uszkodzony. Zainstaluj sprawdzone wydanie Putkina.");
        case "incompatible_release": return qsTr("Dane Signala wymagają zgodnego wydania. Nie można cofnąć historii ani kluczy konta.");
        case "unsupported_schema": return qsTr("Historia wymaga nowszej wersji Putkina.");
        case "account_identity_unknown": return qsTr("Nie można potwierdzić tożsamości konta Signal.");
        case "invalid_event": return qsTr("Nie można odczytać zdarzenia Signal. Odbiór został zatrzymany.");
        case "unsafe_path": case "storage_error": return qsTr("Prywatny katalog Signala jest niedostępny.");
        case "invalid_config": return qsTr("Nieprawidłowa konfiguracja Signala.");
        case "multiple_accounts": return qsTr("Katalog Signala zawiera więcej niż jedno konto.");
        case "timeout": return qsTr("Przekroczono czas oczekiwania na usługę Signal.");
        default: return qsTr("Utracono połączenie z usługą Signal.");
        }
    }
    function clearQr(): void { qrModules = []; qrExpiresAt = 0; qrAttempt = ""; }
    function accountRequest(method: string, params: var): string {
        actionError = "";
        const id = backend.request(method, params);
        if (id) accountRequests[id] = true;
        else actionError = "not_ready";
        return id;
    }
    function configure(values: var): string { return accountRequest("account.configure", values); }
    function startLink(deviceName: string): string { return accountRequest("account.link.start", {deviceName: deviceName}); }
    function cancelLink(): string {
        clearQr();
        return accountRequest("account.link.cancel", {attemptId: linkAttempt});
    }
    function refreshAccount(): string {
        if (!backend.generation) {
            actionError = backend.retry() ? "" : "not_ready";
            return "";
        }
        return accountRequest("account.refresh", {});
    }
    function clearHistory(): string {
        return accountRequest("account.history.clear", {accountId: accountId, confirm: "delete-local-history"});
    }
    function retry(): bool { return backend.retry(); }
    function status(): string { return backend.request("service.status", {}); }
    function cancel(requestId: string): string { return backend.request("request.cancel", {id: requestId}); }
    signal response(string requestId, var result, var error)
    signal changed(string name, var data)
    signal reset()
    readonly property Connections events: Connections {
        target: root.backend
        function onResponse(requestId: string, result: var, error: var): void {
            if (root.accountRequests[requestId]) {
                delete root.accountRequests[requestId];
                if (error) root.actionError = error.code;
            }
            root.response(requestId, result, error);
        }
        function onEvent(name: string, data: var): void {
            // QR is consumed here only; never forwarded to notification/history subscribers.
            if (name === "account.link.qr") {
                if (data.attemptId !== root.linkAttempt || !Array.isArray(data.modules)) return;
                const rows = data.modules;
                if (rows.length < 21 || rows.length > 177 || rows.some(row => typeof row !== "string"
                        || row.length !== rows.length || /[^01]/.test(row))) return;
                root.qrAttempt = data.attemptId;
                root.qrExpiresAt = data.expiresAtMs;
                root.qrModules = rows;
                return;
            }
            if (name === "account.link.cleared") { root.clearQr(); return; }
            root.changed(name, data);
        }
        function onGenerationChanged(): void { root.clearQr(); root.accountRequests = ({}); root.reset(); }
        function onServiceStateChanged(): void {
            if (root.state === "failed" || root.state === "stopping" || root.state === "disabled") root.clearQr();
        }
    }
    readonly property Timer qrExpiry: Timer {
        interval: Math.max(1, root.qrExpiresAt - Date.now())
        running: root.qrModules.length > 0
        // The bridge owns the monotonic deadline and process cleanup. A local
        // clock adjustment must not turn expiry into a user cancellation.
        onTriggered: root.clearQr()
    }
    function conversations(before: var, limit: int): string {
        return backend.request("conversations.page", {before: before, limit: limit || 50});
    }
    function messages(conversationId: string, before: var, limit: int): string {
        return backend.request("messages.page", {conversationId: conversationId, before: before, limit: limit || 50});
    }
    function message(messageId: string): string { return backend.request("message.get", {messageId: messageId}); }
    function openConversation(target: var): string { return backend.request("conversation.open", target); }
    function draft(conversationId: string): string { return backend.request("draft.get", {conversationId: conversationId}); }
    function setDraft(conversationId: string, text: string, expectedRevision: real): string {
        return backend.request("draft.set", {conversationId: conversationId, text: text, expectedRevision: expectedRevision});
    }
    function sendText(conversationId: string, text: string, operationId: string): string {
        return backend.request("message.send", {conversationId: conversationId, text: text, operationId: operationId});
    }
    function operation(operationId: string): string { return backend.request("operation.status", {operationId: operationId}); }
    function cancelOperation(operationId: string): string { return backend.request("operation.cancel", {operationId: operationId}); }
    function retryOperation(operationId: string): string { return backend.request("operation.retry", {operationId: operationId}); }
}
