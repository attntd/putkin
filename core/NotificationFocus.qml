import QtQuick

QtObject {
    id: root
    required property var service
    required property var panels
    required property var barFocus
    property string screenName: ""
    property int focusReason: Qt.TabFocusReason
    property int replyHistoryKey: 0
    signal entered(string name)
    function focus(reason = Qt.TabFocusReason): string {
        if (!service || service.locked) return "";
        return enter(reason) || openCenter(reason);
    }
    function openCenter(reason = Qt.TabFocusReason): string {
        return panels.open("notifications", null, null, reason) ? panels.screenName : "";
    }
    function closeCenter(): void {
        if (panels.activeId === "notifications") panels.close(true);
        close();
    }
    function close(): void {
        screenName = ""; replyHistoryKey = 0;
        if (service && service.messaging) Object.values(service.messaging.replies).forEach(reply => { reply.editing = false; });
    }
    function enterReply(entry: var, reason: int): bool {
        if (!service || service.locked || !entry || !entry.shown || !service.invoke(entry, "reply")) return false;
        panels.close(false); barFocus.close();
        focusReason = reason; replyHistoryKey = entry.historyKey;
        screenName = entry.monitorName;
        entered(screenName);
        return true;
    }
    function enter(reason = Qt.TabFocusReason): string {
        if (!service || service.locked) return "";
        const preferred = service.chooseScreen();
        const entry = preferred && service.visibleOn(preferred.name).length ? service.visibleOn(preferred.name)[0]
            : service.entries.find(value => value.shown);
        if (!entry) return "";
        focusReason = reason;
        replyHistoryKey = 0;
        panels.close(false);
        barFocus.close();
        screenName = entry.monitorName;
        entered(screenName);
        return screenName;
    }
    onScreenNameChanged: { if (service) service.keyboardMonitor = screenName; }
    readonly property Connections notifications: Connections {
        target: root.service
        function onChanged(): void { if (root.screenName && !root.service.visibleOn(root.screenName).length) root.close(); }
        function onLockedChanged(): void { if (root.service.locked) root.close(); }
    }
    readonly property Connections panelChanges: Connections {
        target: root.panels
        function onActiveIdChanged(): void {
            if (root.service) root.service.centerVisible = root.panels.activeId === "notifications";
            if (root.panels.activeId) root.close();
        }
    }
    readonly property Connections barChanges: Connections {
        target: root.barFocus
        function onScreenNameChanged(): void { if (root.barFocus.screenName) root.close(); }
    }
    onServiceChanged: { if (service) service.centerVisible = panels.activeId === "notifications"; }
    Component.onCompleted: { if (service) service.centerVisible = panels.activeId === "notifications"; }
    Component.onDestruction: { if (service) { service.keyboardMonitor = ""; service.centerVisible = false; } }
}
