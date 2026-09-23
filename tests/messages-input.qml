import QtQuick
import "../core"
import "../services"
import "../preview"
import "../modules/messages"

Item {
    id: root
    width: 980
    height: 720
    readonly property bool ready: adapter.draftReady && !adapter.loading && hub.conversations.length === 60
    MockMessagingBackend { id: backend }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    MessagesView { id: view; anchors.fill: parent; hub: hub }
    Component.onCompleted: {
        backend.seed();
        const original = backend.rows[0];
        backend.rows = Array.from({length: 60}, (_, i) => Object.assign({}, original, {
            conversationId: i === 0 ? "chat-a" : "chat-" + i,
            title: "Rozmowa " + (i + 1), activityTimestampMs: original.activityTimestampMs - i
        }));
        adapter.clear();
        hub.openConversation(adapter.address("chat-a"));
    }
}
