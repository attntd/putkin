pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "modules/messages"
import "modules/notifications"

ShellRoot {
    id: root
    property bool captured: false
    property int created: 0
    property int destroyed: 0
    property var metrics: ({})
    property var selectedReply: null
    property bool centerShown: false
    readonly property bool nativeMode: Quickshell.env("PUTKIN_SIGNAL_NATIVE") === "1"
    SettingsFile { id: settingsFile }
    Settings { id: settings; storage: settingsFile }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    QtObject {
        id: panels
        property string activeId: ""
        property string screenName: ""
        signal sessionChanged()
        function close(_returnFocus: bool): void { activeId = ""; screenName = ""; sessionChanged(); }
    }
    QtObject { id: barFocus; property string screenName: ""; function close(): void { screenName = ""; } }
    NotificationFocus { id: notificationFocus; service: notifications; panels: panels; barFocus: barFocus }
    property var nativeNotifications: null
    Component.onCompleted: {
        if (nativeMode) {
            const component = Qt.createComponent("modules/notifications/NotificationWindows.qml");
            if (component.status !== Component.Ready) throw new Error(component.errorString());
            nativeNotifications = component.createObject(root, {service: notifications, controller: notificationFocus, panels: panels});
        }
    }
    FloatingWindow {
        visible: root.centerShown
        title: "Centrum testowe S11"
        implicitWidth: 400; implicitHeight: 700
        color: Theme.background
        Controls.ScrollView {
            id: centerScroll
            anchors.fill: parent
            contentWidth: availableWidth
            NotificationCenter { id: centerView; width: centerScroll.availableWidth; service: notifications }
        }
    }
    Connections {
        target: backend
        function onResponse(_id: string, result: var, _error: var): void {
            if (result && result.retentionTimers !== undefined) root.metrics = result;
        }
    }
    property string requestError: ""
    Connections { target: service; function onResponse(_id: string, _result: var, error: var): void { if (error) root.requestError = error.code; } }
    readonly property var testController: controller
    SignalBackend { id: backend; helperArguments: ["--test-scenario", Quickshell.env("PUTKIN_SIGNAL_TEST_SCENARIO")] }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    QtObject { id: monitor; property string focusedMonitorName: "" }
    MessagesController { id: controller; hub: hub; screens: Quickshell.screens; monitorService: monitor; loader: loader; blocked: notifications.locked }
    LazyLoader { id: loader; MessagesWindow {
        controller: root.testController
        Component.onCompleted: root.created++
        Component.onDestruction: root.destroyed++
    } }
    NotificationBackend { id: noticesBackend }
    NotificationService { id: notifications; backend: noticesBackend; screens: Quickshell.screens; monitorService: monitor; messaging: notices }
    SignalNotifications { id: notices; service: service; notifications: notifications; messagesController: controller }
    FloatingWindow {
        id: cover
        title: "Syntetyczne inne okno S11"
        implicitWidth: 300; implicitHeight: 180
        color: Theme.background
        TextInput { id: coverItem; objectName: "s11Target"; anchors.fill: parent; color: Theme.text; focus: true }
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const view = controller.window ? controller.window.view : null;
            let focused = view && view.Window.window ? view.Window.window.activeFocusItem : null;
            let listFocused = false;
            for (let item = focused; item; item = item.parent) if (item.objectName === "conversationList") listFocused = true;
            return JSON.stringify({state: service.state, pid: backend.processId, generation: backend.generation, accountId: service.accountId,
                loaded: controller.loaded, interactive: controller.interactive, selected: adapter.selectedRoute,
                unread: hub.unreadCount, entries: notifications.entries.length, history: notifications.history,
                pending: !!notices.requestId || Object.keys(notices.pending).length > 0 || Object.keys(adapter.requests).length > 0,
                reading: view ? view.readingEnabled : false, active: view ? view.Window.active : false,
                minimized: controller.window ? controller.window.minimized : false, locked: notifications.locked,
                visibleUnread: view ? view.historyView.visibleUnread() : [],
                attachments: adapter.draftAttachments, mediaBusy: adapter.mediaBusy, draftReady: adapter.draftReady, mediaPreview: view ? !!view.previewAttachment : false, count: adapter.messages.count, mediaRows: Array.from({length: adapter.messages.count}, (_, i) => JSON.parse(adapter.messages.get(i).attachmentsJson)), statuses: Array.from({length: adapter.messages.count}, (_, i) => adapter.messages.get(i).status),
                rows: Array.from({length: adapter.messages.count}, (_, i) => Object.assign({}, adapter.messages.get(i))),
                editing: adapter.editingMessage, composerText: adapter.composerText, draftText: adapter.draftText, typing: adapter.typingAuthors,
                canSend: adapter.canSend, selectedConversation: adapter.selectedConversation, capabilities: service.capabilities,
                directory: adapter.directory, groupDetails: adapter.groupDetails, groupOperations: adapter.groupOperations, directoryBusy: adapter.directoryBusy, replyAllowed: Object.values(notices.records).some(r => r.canSend),
                requestError: root.requestError, lastError: adapter.lastError, captured: root.captured,
                created: root.created, destroyed: root.destroyed,
                screen: controller.screen ? controller.screen.name : "",
                screens: Quickshell.screens.map(s => ({name: s.name, width: s.width, height: s.height})),
                presentationOpacity: view ? view.parent.opacity : 0, geometry: view ? {width: view.width, height: view.height} : null,
                focus: view && view.Window.window && view.Window.window.activeFocusItem ? view.Window.window.activeFocusItem.objectName : "",
                listFocused: listFocused,
                nextCursor: adapter.nextCursor, delegates: view ? view.historyView.contentItem.children.length : 0,
                accent: Theme.accent.toString(), secondary: Theme.accentSecondary.toString(), settingsReady: settings.ready,
                settingsSaving: settings.saving, coverActive: coverItem.Window.active, coverText: coverItem.text,
                metrics: root.metrics, qmlTimers: Number(backend.startup.running) + Number(service.qrExpiry.running) + Number(notices.batch.running) + Number(controller.release.running),
                replyScreen: notificationFocus.screenName, reply: root.selectedReply ? {ready: root.selectedReply.ready, text: root.selectedReply.text, state: root.selectedReply.state,
                    editing: root.selectedReply.editing, pending: root.selectedReply.pending, dirty: root.selectedReply.dirty} : null});
        }
        function receive(wire: string): void { backend.request("test.echo", {receive: JSON.parse(wire)}); }
        function select(index: int): bool { return controller.openConversation(adapter.conversations[index].route); }
        function activate(): void { if (controller.window) controller.window.view.Window.window.requestActivate(); }
        function coverMessages(): void { coverItem.Window.window.requestActivate(); }
        function minimize(value: bool): void { if (controller.window) controller.window.minimized = value; }
        function scroll(index: int): void { if (controller.window) controller.window.view.historyView.positionViewAtIndex(index, ListView.Beginning); }
        function close(): void { controller.close(); }
        function center(value: bool): void { notifications.centerVisible = value; }
        function locked(value: bool): void { notifications.locked = value; }
        function draft(text: string): void { adapter.editDraft(text); }
        function send(): bool { return adapter.send(); }
        function createGroup(name: string, member: string): bool { controller.open(""); return adapter.createGroup(name, [member], ""); }
        function group(action: string, params: string): bool { return adapter.groupAction(action, JSON.parse(params)); }
        function details(): void { if (controller.window) { adapter.inspectGroup(); controller.window.view.detailsOpen = true; } }
        function directoryRefresh(): void { adapter.refreshDirectory(); }
        function mute(value: bool): void { adapter.muteConversation(value); }
        function reply(text: string): bool {
            const row = notifications.history.find(v => v.messageReference);
            if (!row || !notices.invoke(row.messageReference, "reply")) return false;
            const session = notices.session(row.messageReference);
            if (!session.ready) return false;
            session.edit(text); return session.send();
        }
        function remove(mid: string, scope: string): bool { return adapter.deleteMessage(mid, scope); }
        function expiration(seconds: int): void { adapter.setExpiration(seconds); }
        function edit(mid: string): bool { return adapter.beginEdit(mid); }
        function compose(text: string): void { adapter.editComposer(text); }
        function submit(): bool { return adapter.sendComposer(); }
        function react(mid: string, emoji: string, remove: bool): bool { return adapter.react(mid, emoji, remove); }
        function quote(mid: string): void { adapter.replyTo(mid); }
        function actions(mid: string): void { if (controller.window) controller.window.view.historyView.actionsMessageId = mid; }
        function showDetails(value: bool): void { if (controller.window) controller.window.view.detailsOpen = value; }
        function accent(primary: string, secondary: string): void { Theme.appearance = Object.assign({}, Theme.appearance, {accent: primary, accentSecondary: secondary}); }
        function reload(): void { Quickshell.reload(true); }
        function capture(path: string): bool {
            root.captured = false;
            return !!controller.window && controller.window.view.grabToImage(result => { root.captured = result.saveToFile(path); });
        }
        function open(index: int, screen: string): bool { return controller.openConversation(adapter.conversations[index].route, screen); }
        function openList(screen: string): bool { return controller.open(screen); }
        function notificationOpen(index: int): bool {
            const row = notifications.history[index];
            return !!row && notifications.invoke(notifications.historyEntry(row.historyKey), "open");
        }
        function openRoute(cid: string, screen: string): bool { return controller.openConversation({serviceId: "signal", accountId: service.accountId, conversationId: cid}, screen); }
        function more(): void { adapter.loadMore(); }
        function monitor(name: string): void { monitor.focusedMonitorName = name; }
        function metrics(): void { backend.request("test.metrics", {}); }
        function replyOpen(index: int): bool {
            const row = notifications.history[index];
            if (!row) return false;
            const entry = notifications.historyEntry(row.historyKey);
            const accepted = root.nativeMode ? notificationFocus.enterReply(entry, Qt.TabFocusReason) : notifications.invoke(entry, "reply");
            if (accepted) root.selectedReply = notices.session(row.messageReference);
            return accepted;
        }
        function replyDraft(text: string): void { if (root.selectedReply) root.selectedReply.edit(text); }
        function replySend(): bool { return !!root.selectedReply && root.selectedReply.send(); }
        function replyClose(): void { notificationFocus.close(); }
        function toastFocus(): string { return notificationFocus.enter(); }
        function notificationTimeout(value: int): void { notifications.defaultTimeout = value; }
        function centerFocus(): void { centerView.focusInitial(); }
        function notificationSnapshot(): string {
            function findStack(item) {
                if (!item) return null;
                if (typeof item.cardAt === "function") return item;
                for (const child of item.children || []) { const found = findStack(child); if (found) return found; }
                return null;
            }
            let stack = null;
            if (root.nativeNotifications) {
                for (const variant of root.nativeNotifications.instances) {
                    if (variant.modelData.name === (notificationFocus.screenName || monitor.focusedMonitorName) && variant.loader.item)
                        stack = findStack(variant.loader.item.contentItem);
                }
            }
            const view = root.centerShown ? centerView : stack;
            const card = view ? view.cardAt(0) : null;
            const focused = view && view.Window.window ? view.Window.window.activeFocusItem : null;
            return JSON.stringify({focus: focused ? focused.objectName : "", center: root.centerShown, screen: notificationFocus.screenName,
                stackFound: !!stack, stackCount: stack ? stack.count : -1,
                variants: root.nativeNotifications ? root.nativeNotifications.instances.map(v => ({name: v.modelData.name, loaded: !!v.loader.item,
                    children: v.loader.item ? v.loader.item.contentItem.children.map(c => ({name: c.objectName, count: c.count === undefined ? -1 : c.count, cardAt: typeof c.cardAt})) : []})) : [],
                firstAction: card && card.firstActionControl ? card.firstActionControl.objectName : "",
                actions: card ? Array.from({length: card.actionItems.count}, (_, i) => {
                    const action = card.actionAt(i);
                    return action ? {name: action.objectName, visible: action.visible, enabled: action.enabled} : null;
                }) : []});
        }
        function appearance(action: string, primary: string, secondary: string): bool {
            if (action === "cancel") { settings.cancelEdit(); return true; }
            settings.beginEdit(); settings.setColor("accent", primary); settings.setColor("accentSecondary", secondary);
            return action === "save" ? settings.save() : true;
        }
        function centerWindow(value: bool): void { root.centerShown = value; notifications.centerVisible = value; }
        function clearNotifications(): void { notifications.clearHistory(); }
        function expireToasts(): void { notifications.entries.slice().forEach(row => notifications.expire(row)); }
        function editorFocus(): void { if (controller.window) controller.window.view.focusComposer(); }
        function controlGeometry(name: string): string {
            if (!controller.window) return "null";
            const view = controller.window.view;
            function find(item) {
                if (!item.visible) return null;
                if (item.objectName === name) return item;
                for (const child of item.children || []) { const result = find(child); if (result) return result; }
                return null;
            }
            const item = find(view);
            if (!item) return "null";
            const point = item.mapToItem(view, 0, 0);
            return JSON.stringify({x: point.x, y: point.y, width: item.width, height: item.height});
        }
        function trace(phase: string): void { console.log("S11_PHASE", phase); }
        function quit(): void { Qt.quit(); }
    }
}
