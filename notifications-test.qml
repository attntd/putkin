pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "preview"
import "components" as UI

ShellRoot {
    id: root
    readonly property real generation: Date.now()
    NotificationBackend { id: backend }
    NotificationService { id: service; backend: backend; screens: view.scene.coordinator.screens; monitorService: view.scene.backend }
    PanelPreviewWindow { id: view; notifications: service }
    NotificationIpc { service: service; controller: view.scene.notificationController }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            return JSON.stringify({ generation: root.generation, available: service.available,
                error: service.errorText, phase: backend.phase, serverLoaded: backend.serverLoaded,
                watcherPid: backend.watcherPid, dnd: service.dnd, tracked: backend.tracked.length,
                loaded: view.scene.notificationStack !== null,
                created: view.scene.toastsCreated, destroyed: view.scene.toastsDestroyed,
                keyboard: view.scene.notificationController.screenName,
                center: view.scene.coordinator.activeId === "notifications", history: service.history,
                unread: service.unreadCount,
                bell: (view.scene.bar.notificationsButton.contentItem as UI.Glyph).symbol,
                entries: service.entries.map(entry => ({ id: entry.notificationId, summary: entry.summary,
                    body: entry.body, actions: entry.actions, monitor: entry.monitorName, shown: entry.shown,
                    deadline: entry.deadline, image: entry.imageSource, critical: entry.critical })) });
        }
        function dismiss(id: int): void { service.dismiss(service.find(id)); }
        function invoke(id: int, action: string): bool { return service.invoke(service.find(id), action); }
        function dnd(enabled: bool): void { service.dnd = enabled; }
        function clear(): void { service.clear(); }
        function timeout(value: int): void { service.defaultTimeout = value; }
        function monitor(name: string): void { view.scene.backend.focusedMonitorName = name; }
        function screens(count: int): void { view.scene.coordinator.screens = count === 0 ? [] : count === 1 ? [view.scene.secondScreen] : [view.scene.firstScreen, view.scene.secondScreen]; }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
