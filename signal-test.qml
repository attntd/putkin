import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: root
    property bool showWindow: false
    property int received: 0
    property var replies: []
    SignalBackend {
        id: backend
        helperArguments: Quickshell.env("PUTKIN_SIGNAL_TEST_SCENARIO")
            ? ["--test-scenario", Quickshell.env("PUTKIN_SIGNAL_TEST_SCENARIO")] : []
        onEvent: (name, data) => { if (name === "test.receive") root.received++; }
    }
    SignalService {
        id: service
        backend: backend
        onResponse: (requestId, result, error) => { root.replies = root.replies.concat([{id: requestId, result: result, error: error}]); }
    }
    LazyLoader {
        active: root.showWindow
        FloatingWindow { visible: true; implicitWidth: 320; implicitHeight: 200 }
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({state: service.state, account: service.accountState, error: service.errorCode,
                pid: backend.processId, generation: backend.generation, received: root.received, replies: root.replies,
                accountId: service.accountId, schemaVersion: service.schemaVersion});
        }
        function window(visible: bool): void { root.showWindow = visible; }
        function reload(hard: bool): void { Quickshell.reload(hard); }
        function echo(text: string): string { return backend.request("test.echo", {text: text}); }
        function conversations(): string { return service.conversations(null, 50); }
        function messages(conversationId: string): string { return service.messages(conversationId, null, 50); }
        function draft(conversationId: string): string { return service.draft(conversationId); }
        function setDraft(conversationId: string, text: string, revision: string): string {
            return service.setDraft(conversationId, text, Number(revision));
        }
        function sendText(conversationId: string, text: string, operationId: string): string {
            return service.sendText(conversationId, text, operationId);
        }
        function operation(operationId: string): string { return service.operation(operationId); }
        function retry(): bool { return service.retry(); }
        function quit(): void { Qt.quit(); }
    }
}
