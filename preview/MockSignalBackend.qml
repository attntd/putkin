import QtQuick

QtObject {
    id: root
    property string generation: "preview"
    property string serviceState: "idle"
    property string accountState: "unlinked"
    property string accountId: ""
    property int schemaVersion: 1
    property string cliVersion: "0.14.8"
    property string errorCode: ""
    property var capabilities: ["account.configure", "account.link.start", "account.link.cancel", "account.refresh", "account.history.clear"]
    property var configuration: ({enabled: false, deviceName: "Putkin"})
    property string linkAttempt: ""
    property string linkError: ""
    property bool reconciling: false
    readonly property bool ready: serviceState === "ready"
    property var calls: []
    property int counter: 0
    signal response(string requestId, var result, var error)
    signal event(string name, var data)
    function retry(): bool { serviceState = "idle"; errorCode = ""; return true; }
    function request(method: string, params: var): string {
        const id = "mock-" + (++counter);
        calls = calls.concat([{method: method, params: params}]);
        if (method === "account.link.start") {
            linkAttempt = "preview-attempt";
            accountState = "linking";
        } else if (method === "account.link.cancel") {
            event("account.link.cleared", {attemptId: linkAttempt});
            linkAttempt = "";
            accountState = "unlinked";
        } else if (method === "account.configure") {
            configuration = Object.assign({}, configuration, params);
            serviceState = configuration.enabled ? "ready" : "disabled";
        }
        Qt.callLater(() => root.response(id, {accepted: true}, null));
        return id;
    }
    function reset(): void {
        generation += "x";
        serviceState = "idle"; accountState = "unlinked"; accountId = "";
        configuration = ({enabled: false, deviceName: "Putkin"});
        linkAttempt = ""; linkError = ""; errorCode = ""; calls = [];
    }
}
