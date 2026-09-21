import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var controller
    readonly property IpcHandler handler: IpcHandler {
        target: "messages"
        function open(): bool { return root.controller.open(""); }
        function openConversation(serviceId: string, accountId: string, conversationId: string): bool {
            return root.controller.openConversation({serviceId: serviceId, accountId: accountId, conversationId: conversationId});
        }
    }
}
