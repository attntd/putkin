import QtQuick
import "../core/Icons.js" as Icons

QtObject {
    id: root
    required property var service
    required property var notification
    required property real notificationId
    property int historyKey: 0
    property bool unread: true
    property string monitorName: ""
    property bool shown: false
    property real receivedAt: Date.now()
    property real deadline: 0
    property real remaining: 0
    readonly property var messageReference: notification && notification.internal === true ? notification.messageReference || null : null
    readonly property real messageTimestamp: messageReference ? notification.messageTimestamp : 0
    readonly property var replySession: service.messageSession(messageReference)
    readonly property bool paused: (shown && service.keyboardMonitor === monitorName) || !!(replySession && (replySession.editing || replySession.busy))
    property var actionLabels: null
    property var closedSnapshot: null
    function snapshot(): var {
        return {historyKey: historyKey, appName: appName, applicationId: applicationId, summary: summary, body: body, critical: critical,
            iconName: iconName, imageSource: imageSource, actions: actions, receivedAt: receivedAt, unread: unread,
            messageReference: messageReference, messageTimestamp: messageTimestamp};
    }
    readonly property bool critical: notification !== null && notification.urgency === 2
    readonly property string appName: limit(notification ? notification.appName : "", 128) || qsTr("Aplikacja")
    readonly property string applicationId: notification && service.applicationService ? service.applicationService.identify(notification) : ""
    readonly property string summary: (notification ? notification.summary : "") || qsTr("Powiadomienie")
    readonly property string body: notification ? notification.body : ""
    readonly property string iconName: Icons.application(notification ? notification.appIcon : "", appName, "", [])
    readonly property string imageSource: {
        const source = notification ? notification.image : "";
        return source.indexOf("image://") === 0 || source.indexOf("file:///") === 0 ? source : "";
    }
    readonly property var actions: {
        if (messageReference) return service.messageActions(messageReference);
        const values = notification ? notification.actions : [];
        return values.slice(0, 8).filter(action => action.identifier !== "inline-reply" && action.identifier.length <= 256).map(action => ({
            identifier: action.identifier,
            text: limit(actionLabels && actionLabels[action.identifier] !== undefined ? actionLabels[action.identifier] : action.text, 128)
                || (action.identifier === "default" ? qsTr("Otwórz") : qsTr("Akcja"))
        }));
    }
    function limit(value: string, length: int): string { return value.length > length ? value.slice(0, length - 1) + "…" : value; }
    function resetTimeout(timeout: real): void {
        receivedAt = Date.now();
        const duration = critical || timeout === 0 ? 0 : timeout < 0 ? service.defaultTimeout : timeout;
        deadline = duration > 0 ? receivedAt + Math.min(duration, 2147483647) : 0;
        remaining = Math.max(0, deadline - receivedAt);
        expiry.stop();
        if (deadline > 0 && !paused) { expiry.interval = Math.max(1, deadline - Date.now()); expiry.start(); }
    }
    onPausedChanged: {
        if (deadline <= 0) return;
        if (paused) { remaining = Math.max(1, deadline - Date.now()); expiry.stop(); }
        else { deadline = Date.now() + remaining; expiry.interval = Math.max(1, remaining); expiry.start(); }
    }
    function updated(): void {
        if (!notification) return;
        actionLabels = null;
        resetTimeout(notification.expireTimeout);
        service.updated(root);
    }
    readonly property Timer expiry: Timer { onTriggered: root.service.expire(root) }
    readonly property Connections changes: Connections {
        target: root.notification
        function onClosed(_reason: int): void { root.service.remove(root); }
        function onAppNameChanged(): void { root.updated(); }
        function onDesktopEntryChanged(): void { root.updated(); }
        function onSummaryChanged(): void { root.updated(); }
        function onBodyChanged(): void { root.updated(); }
        function onExpireTimeoutChanged(): void { root.updated(); }
        function onUrgencyChanged(): void { root.updated(); }
        function onActionsChanged(): void { root.updated(); }
        function onImageChanged(): void { root.updated(); }
        function onResidentChanged(): void { root.updated(); }
        function onTransientChanged(): void { root.updated(); }
        function onHintsChanged(): void { root.updated(); }
    }
}
