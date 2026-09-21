import QtQuick
import QtQml.Models
import "../core"
import "../core/ConversationRoute.js" as Route

QtObject {
    id: root
    required property var backend
    required property var screens
    required property var monitorService
    property var applicationService: null
    property bool dnd: false
    property bool locked: false
    property var messaging: null
    property string keyboardMonitor: ""
    property int defaultTimeout: 6000
    readonly property int visibleLimit: 3
    readonly property int queueLimit: 12
    property var entries: []
    property var history: []
    property bool centerVisible: false
    readonly property int unreadCount: history.filter(entry => entry.unread).length
    readonly property int historyLimit: 100
    property int nextHistoryKey: 1
    property bool balancing: false
    property int localId: -1
    readonly property bool available: backend.available
    readonly property string errorText: backend.errorText
    readonly property string statusText: !available ? errorText || qsTr("Uruchamianie powiadomień…")
        : dnd ? qsTr("Nie przeszkadzać · tylko krytyczne") : qsTr("Powiadomienia włączone")
    signal changed()

    function messageActions(ref: var): var { return ref && messaging && !locked ? messaging.actions(ref) : []; }
    function messageSession(ref: var): var { return ref && messaging && messaging.revision >= 0 ? messaging.session(ref) : null; }
    function hasMessageToast(ref: var): bool { return entries.some(row => row.messageReference && Route.equal(row.messageReference, ref)); }
    function publishMessage(ref: var, title: string, body: string, timestamp: real, arrival: bool, toast: bool, muted: bool, image: string): void {
        if (!messaging || !messaging.valid(ref)) return;
        const archived = history.find(row => row.messageReference && Route.equal(row.messageReference, ref));
        if (archived && (arrival ? archived.messageTimestamp > timestamp : archived.messageReference.messageId !== ref.messageId)) return;
        if (!arrival && !archived) return;
        const previous = entries.find(row => row.messageReference && Route.equal(row.messageReference, ref));
        const safeTitle = locked ? "Signal" : title.slice(0, 512);
        const safeBody = locked ? qsTr("Nowa wiadomość") : body.slice(0, 4096);
        const safeImage = !locked && typeof image === "string" ? image : "";
        if (previous) {
            previous.notification.messageReference = Object.assign(Route.copy(ref), {messageId: ref.messageId});
            previous.notification.messageTimestamp = timestamp;
            previous.notification.summary = safeTitle; previous.notification.body = safeBody;
            previous.notification.image = safeImage;
            if (arrival) previous.resetTimeout(defaultTimeout);
            remember(previous);
            if (muted || locked) expire(previous);
            return;
        }
        if (archived && (!arrival || !toast || dnd || locked || muted)) {
            history = history.map(row => row.historyKey === archived.historyKey ? Object.assign({}, row, {
                summary: safeTitle, body: safeBody, imageSource: safeImage, messageReference: Object.assign(Route.copy(ref), {messageId: ref.messageId}),
                messageTimestamp: timestamp, receivedAt: arrival ? Date.now() : row.receivedAt, unread: arrival ? !centerVisible : row.unread}) : row);
            return;
        }
        const notice = localNotification.createObject(root, {appName: "Signal", appIcon: "signal", summary: safeTitle, body: safeBody,
            image: safeImage,
            urgency: 1, expireTimeout: defaultTimeout, messageReference: Object.assign(Route.copy(ref), {messageId: ref.messageId}), messageTimestamp: timestamp});
        receive(notice, localId--, archived ? archived.historyKey : 0, !toast || muted || locked);
        if (!notice.tracked) notice.destroy();
    }
    function invalidateMessage(ref: var): void {
        const live = entries.find(row => row.messageReference && Route.equal(row.messageReference, ref));
        if (live) { live.notification.summary = "Signal"; live.notification.image = ""; live.notification.body = qsTr("Wiadomość niedostępna"); expire(live); }
        history = history.map(row => row.messageReference && Route.equal(row.messageReference, ref)
            ? Object.assign({}, row, {summary: "Signal", imageSource: "", body: qsTr("Wiadomość niedostępna")}) : row);
    }
    function forgetMessage(ref: var): void {
        const matches = row => row.messageReference && Route.equal(row.messageReference, ref) && row.messageReference.messageId === ref.messageId;
        entries.slice().filter(matches).forEach(row => {
            row.notification.summary = ""; row.notification.body = ""; row.notification.image = "";
            expire(row);
        });
        history = history.filter(row => !matches(row));
    }
    function markMessageRead(ref: var): void {
        // Exact message key: an older phone read must not dismiss a newer card.
        const matches = row => row.messageReference && Route.equal(row.messageReference, ref)
            && row.messageReference.messageId === ref.messageId;
        entries.slice().filter(matches).forEach(row => { row.unread = false; expire(row); });
        history = history.map(row => matches(row) ? Object.assign({}, row, {unread: false}) : row);
    }
    function redactMessages(): void {
        entries.slice().filter(row => row.messageReference).forEach(row => {
            row.notification.summary = "Signal"; row.notification.image = ""; row.notification.body = qsTr("Nowa wiadomość"); expire(row);
        });
        history = history.map(row => row.messageReference ? Object.assign({}, row, {summary: "Signal", imageSource: "", body: qsTr("Nowa wiadomość")}) : row);
    }
    function forgetMessages(): void {
        entries.slice().filter(row => row.messageReference).forEach(row => expire(row));
        history = history.filter(row => !row.messageReference);
    }

    function remember(entry: var): void {
        if (!entry.notification) return;
        // Session history includes short-lived/transient toasts too. Expiring
        // the native object does not remove the user's copy from the center.
        const snapshot = entry.snapshot();
        if (centerVisible) entry.unread = false;
        snapshot.unread = entry.unread;
        snapshot.historyKey = entry.historyKey;
        // Archived rows own plain values, never a native image buffer or action.
        if (!snapshot.messageReference || locked) snapshot.imageSource = "";
        snapshot.actions = [];
        history = [snapshot].concat(history.filter(value => value.historyKey !== entry.historyKey))
            .sort((a, b) => b.receivedAt - a.receivedAt || b.historyKey - a.historyKey).slice(0, historyLimit);
    }
    function rememberSuppressed(notification: var, id: real, key: int): void {
        const entry = entryComponent.createObject(root, {service: root, notification: notification,
            notificationId: id, historyKey: key || nextHistoryKey++});
        remember(entry);
        entry.notification = null;
        entry.destroy();
    }
    function historyEntry(key: int): var {
        return entries.find(entry => entry.historyKey === key) || history.find(entry => entry.historyKey === key) || null;
    }
    function dismissHistory(key: int): void {
        const entry = entries.find(value => value.historyKey === key);
        if (entry) dismiss(entry);
        history = history.filter(value => value.historyKey !== key);
    }
    function clearHistory(): void { history.slice().forEach(entry => dismissHistory(entry.historyKey)); }
    function invokeHistory(key: int, identifier: string): bool {
        if (!invoke(historyEntry(key), identifier)) return false;
        // Native actions may synchronously replace the live entry with its
        // archive. Consume by history key so either representation is removed.
        dismissHistory(key);
        return true;
    }
    function markAllRead(): void {
        entries.forEach(entry => { entry.unread = false; });
        history = history.map(entry => Object.assign({}, entry, {unread: false}));
    }
    function markRead(entry: var): void {
        if (!entry) return;
        entry.unread = false;
        history = history.map(value => value.historyKey === entry.historyKey
            ? Object.assign({}, value, {unread: false}) : value);
    }

    function notifyError(title: string, message: string): void {
        if (!message) return;
        const previous = entries.find(entry => entry.notification && entry.notification.internal === true && !entry.messageReference && entry.summary === title);
        if (previous) {
            previous.notification.body = message;
            return;
        }
        const notice = localNotification.createObject(root, {summary: title, body: message});
        receive(notice, localId--);
        if (!notice.tracked) notice.destroy();
    }

    function slots(screen: var): int {
        return screen && screen.width >= 160 ? Math.max(0, Math.min(visibleLimit,
            Math.floor((screen.height - Metrics.barHeight - Metrics.panelGap) / (Metrics.toastMinHeight + Metrics.panelGap)))) : 0;
    }
    function chooseScreen(): var {
        return screens.find(screen => screen.name === monitorService.focusedMonitorName && slots(screen) > 0)
            || screens.find(screen => slots(screen) > 0) || null;
    }
    function visibleOn(name: string): var { return entries.filter(entry => entry.shown && entry.monitorName === name); }
    function find(id: real): var { return entries.find(entry => entry.notificationId === id) || null; }
    function receive(notification, id, key = 0, suppress = false) {
        const screen = chooseScreen();
        if (!available && notification.internal !== true) { notification.expire(); return; }
        if (suppress || !screen || (dnd && notification.urgency !== 2)) {
            rememberSuppressed(notification, id, key);
            notification.expire();
            return;
        }
        if (entries.length >= visibleLimit + queueLimit) {
            const queued = entries.filter(entry => !entry.shown);
            const victim = queued.find(entry => !entry.critical) || queued[0];
            if (!victim || (notification.urgency !== 2 && victim.critical)) { rememberSuppressed(notification, id, key); notification.expire(); return; }
            expire(victim);
        }
        notification.tracked = true;
        const entry = entryComponent.createObject(root, { service: root, notification: notification,
            notificationId: id, monitorName: screen.name, historyKey: key || nextHistoryKey++ });
        entries = entries.concat([entry]);
        entry.resetTimeout(notification.expireTimeout);
        remember(entry);
        rebalance();
    }
    function remove(entry: var): void {
        if (entries.indexOf(entry) < 0) return;
        const local = entry.notification && entry.notification.internal === true ? entry.notification : null;
        remember(entry);
        entry.closedSnapshot = entry.snapshot();
        if (entry.closedSnapshot.messageReference) {
            entry.closedSnapshot.summary = ""; entry.closedSnapshot.body = "";
        }
        entry.notification = null;
        entries = entries.filter(value => value !== entry);
        rebalance();
        entry.destroy();
        if (local) local.destroy();
    }
    function expire(entry: var): void {
        if (!entry || !entry.notification) return;
        entry.notification.expire();
        // A new Notify has not entered the native ID map until its handler
        // returns. Closing it then sets the reason without emitting closed.
        if (entries.indexOf(entry) >= 0) remove(entry);
    }
    function dismiss(entry: var): void {
        if (entry && entry.notification) { markRead(entry); entry.notification.dismiss(); }
    }
    function clear(): void { entries.slice().forEach(entry => expire(entry)); history = []; }
    function invoke(entry: var, identifier: string): bool {
        if (entry && entry.messageReference) {
            if (locked || !messaging || !history.some(row => row.historyKey === entry.historyKey)) return false;
            return messaging.invoke(entry.messageReference, identifier);
        }
        if (entry && !identifier && applicationService && (entries.indexOf(entry) >= 0 || history.indexOf(entry) >= 0)) {
            if (!applicationService.activate(entry.applicationId || "")) return false;
            markRead(entry);
            return true;
        }
        if (!entry || !entry.notification || entries.indexOf(entry) < 0) return false;
        const action = entry.notification.actions.find(value => value.identifier === identifier && value.identifier !== "inline-reply");
        if (!action) return false;
        markRead(entry);
        action.invoke();
        return true;
    }
    function updated(entry: var): void {
        entry.unread = !centerVisible;
        remember(entry);
        if (dnd && !entry.critical) expire(entry);
        else rebalance();
    }
    function replace(id: real, actions: var, timeout: int): void {
        const entry = find(id);
        if (!entry) return;
        const labels = Object.create(null);
        for (let index = 0; index + 1 < actions.length; index += 2) labels[actions[index]] = actions[index + 1];
        // A monitor delivery can precede native Notify dispatch. Defer once;
        // ordinary property changes also reset the deadline in that case.
        Qt.callLater(() => {
            if (root.entries.indexOf(entry) < 0 || !entry.notification) return;
            entry.actionLabels = labels;
            entry.resetTimeout(timeout);
            root.updated(entry);
        });
    }
    function rebalance(): void {
        if (balancing) return;
        balancing = true;
        const fallback = chooseScreen();
        entries.slice().forEach(entry => {
            if (!screens.some(screen => screen.name === entry.monitorName && slots(screen) > 0)) {
                if (fallback) entry.monitorName = fallback.name;
                else expire(entry);
            }
        });
        let visible = 0;
        const counts = {};
        // Critical arrivals take precedence, with FIFO within each urgency.
        const ordered = entries.filter(entry => entry.critical).concat(entries.filter(entry => !entry.critical));
        ordered.forEach(entry => {
            const screen = screens.find(value => value.name === entry.monitorName);
            const count = counts[entry.monitorName] || 0;
            entry.shown = visible < visibleLimit && count < slots(screen);
            if (entry.shown) { visible++; counts[entry.monitorName] = count + 1; }
        });
        while (entries.filter(entry => !entry.shown).length > queueLimit) {
            const queued = entries.filter(entry => !entry.shown);
            expire(queued.find(entry => !entry.critical) || queued[0]);
        }
        balancing = false;
        changed();
    }
    onDndChanged: { if (dnd) entries.slice().filter(entry => !entry.critical).forEach(entry => expire(entry)); }
    onLockedChanged: { if (locked) { keyboardMonitor = ""; redactMessages(); } else if (messaging) messaging.refresh(); }
    onCenterVisibleChanged: { if (centerVisible) markAllRead(); }
    onAvailableChanged: { if (!available) entries.slice().filter(entry => entry.notification && entry.notification.internal !== true).forEach(entry => expire(entry)); }
    onScreensChanged: rebalance()
    readonly property Component entryComponent: Component { NotificationEntry {} }
    readonly property Component localNotification: Component { LocalNotification {} }
    readonly property Instantiator monitorGeometry: Instantiator {
        model: root.screens
        delegate: QtObject {
            id: screenWatch
            required property var modelData
            readonly property Connections changes: Connections {
                target: screenWatch.modelData
                // QScreen clears geometry before Quickshell publishes its new
                // screens list on hot-unplug. Read the settled list next turn.
                function onWidthChanged(): void { Qt.callLater(root.rebalance); }
                function onHeightChanged(): void { Qt.callLater(root.rebalance); }
            }
        }
    }
    readonly property Connections events: Connections {
        target: root.backend
        function onNotification(value: var, id: real): void { root.receive(value, id); }
        function onReplacement(id: real, actions: var, timeout: int): void { root.replace(id, actions, timeout); }
    }
}
