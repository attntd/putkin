pragma ComponentBehavior: Bound
import QtQuick
import "ConversationRoute.js" as Route

QtObject {
    id: root
    required property var adapters
    property var activeAdapter: adapters.length ? adapters[0] : null
    readonly property var conversations: adapters.reduce((items, adapter) => items.concat(adapter.conversations), []).sort((a, b) => b.activityTimestampMs - a.activityTimestampMs)
    readonly property int unreadCount: conversations.reduce((total, item) => total + item.unreadCount, 0)
    readonly property string lastError: activeAdapter ? activeAdapter.lastError : ""
    signal conversationOpened(var route)
    function adapterFor(route: var): var {
        return Route.valid(route) ? adapters.find(adapter => adapter.serviceId === route.serviceId && adapter.accountId === route.accountId) || null : null;
    }
    function openConversation(route: var): bool {
        const adapter = adapterFor(route);
        if (!adapter) return false;
        activeAdapter = adapter;
        return adapter.selectConversation(Route.copy(route));
    }
    // A static list of explicitly injected adapters, with no discovery/plugin runtime.
    readonly property Instantiator observers: Instantiator {
        model: root.adapters
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConversationOpened(route: var): void {
                if (root.adapterFor(route) === modelData) {
                    root.activeAdapter = modelData;
                    root.conversationOpened(Route.copy(route));
                }
            }
        }
    }
}
