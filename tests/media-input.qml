import QtQuick
import "../modules/messages"
import "../modules/notifications"

Item {
    width: 600; height: 380
    QtObject {
        id: adapter
        objectName: "inputAdapter"
        property bool canSend: true
        property bool draftReady: true
        property bool sending: false
        property string draftText: ""
        property string composerText: ""
        property bool composerBusy: false
        property bool editorActive: false
        property var editingMessage: null
        property var quotedMessage: null
        property var mentionMembers: []
        property int sendCount: 0
        property var selectedRoute: ({conversationId: "synthetic"})
        property var draftAttachments: []
        property int mediaBusy: 0
        property var paths: []
        signal draftLoaded()
        signal composerLoaded()
        function attachFiles(files: var): bool { paths = files; return true; }
        function editDraft(value: string): void { draftText = value; }
        function send(): bool { return true; }
        function editComposer(value: string): void { composerText = value; }
        function sendComposer(): bool { sendCount++; return true; }
        function stopTyping(): void {}
    }
    MessageComposer { width: parent.width; height: 160; adapter: adapter; editingEnabled: true }
    QtObject {
        id: reply
        objectName: "inputReply"
        property string text: ""
        property bool active: true
        property bool editable: true
        property bool editing: true
        property bool canSend: true
        property bool canRetry: false
        property string statusText: ""
        property string state: ""
        property int sendCount: 0
        function edit(value: string): void { text = value; }
        function send(): bool { sendCount++; return true; }
    }
    NotificationReply { y: 200; width: parent.width; session: reply }
}
