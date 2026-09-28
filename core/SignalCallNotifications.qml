pragma ComponentBehavior: Bound
import QtQuick
import "../services"

QtObject {
    id: root
    required property var calls
    required property var notifications
    required property var messagesController
    property var notice: null
    property string noticeCall: ""
    property real historyKey: 0
    readonly property bool locked: notifications.locked
    function clear(): void {
        if (historyKey) notifications.dismissHistory(historyKey);
        historyKey = 0;
        notice = null; noticeCall = "";
    }
    function open(): void {
        if (!calls.current || locked) return;
        messagesController.openConversation({serviceId: "signal", accountId: calls.current.accountId, conversationId: calls.current.conversationId});
    }
    function update(): void {
        if (!calls.incoming || locked) { clear(); return; }
        if (noticeCall === calls.current.callId) return;
        clear();
        // DND leaves the call in the hub; it must not create a critical bypass.
        if (notifications.dnd) return;
        noticeCall = calls.current.callId;
        const id = noticeCall;
        const account = calls.current.accountId;
        const valid = () => !root.locked && root.calls.incoming && root.calls.current.callId === id && root.calls.current.accountId === account;
        const value = noticeComponent.createObject(root, {
            summary: calls.current.title,
            actions: [
                {identifier: "default", text: qsTr("Otwórz"), invoke: () => { if (valid()) root.open(); }},
                {identifier: "accept", text: qsTr("Odbierz"), invoke: () => { if (valid()) { root.calls.accept(); root.open(); } }},
                {identifier: "reject", text: qsTr("Odrzuć"), invoke: () => { if (valid()) root.calls.reject(); }}
            ]
        }) as LocalNotification;
        historyKey = notifications.nextHistoryKey++;
        notifications.receive(value, notifications.localId--, historyKey);
        if (value.tracked) {
            notice = value;
            value.closed.connect(() => { root.notice = null; });
        }
        else value.destroy();
    }
    onLockedChanged: update()
    readonly property Connections changes: Connections {
        target: root.calls
        function onCurrentChanged(): void { root.update(); }
    }
    readonly property Component noticeComponent: Component {
        LocalNotification { appName: "Signal"; appIcon: "signal"; body: qsTr("Połączenie przychodzące"); urgency: 1; expireTimeout: 0; resident: true }
    }
}
