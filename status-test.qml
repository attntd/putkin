import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "preview"
import "modules/tray"

ShellRoot {
    id: root
    readonly property string testGeneration: Date.now().toString() + Math.random().toString()
    UPowerBackend { id: backend }
    BatteryService { id: battery; backend: backend }
    PowerProfileBackend { id: profileBackend }
    PowerProfileService { id: profileService; backend: profileBackend }
    TrayService { id: tray }
    PanelPreviewWindow {
        id: window
        battery: battery
        powerProfiles: profileService
        tray: tray
        trayMenuComponent: Component { TrayMenuAdapter {} }
    }
    IpcHandler {
        target: "probe"
        function icon(index: int): string {
            const item = tray.items.values.find(item => item.id === "app" + index);
            const button = item ? window.scene.bar.trayStrip.buttonFor(item) as TrayButton : null;
            const image = button ? button.contentItem.children.find(child => child.objectName === "trayApplicationIcon") : null;
            const center = image ? image.mapToItem(button, image.width / 2, image.height / 2) : Qt.point(0, 0);
            return JSON.stringify({ready: image ? image.ready : false, symbol: image ? image.symbol : "",
                size: image ? image.iconSize : 0, padding: image ? image.iconPadding : 0,
                centered: image && center.x === button.width / 2 && center.y === button.height / 2});
        }
        function snapshot(): string {
            const scene = window.scene;
            const page = scene.panelHost.window ? scene.panelHost.window.page : null;
            const level = page && page.currentLevel ? page.currentLevel : null;
            return JSON.stringify({
                generation: root.testGeneration, available: battery.available, present: battery.present, percentage: battery.percentage,
                profilesAvailable: profileService.available, profile: profileService.profile,
                profileBusy: profileService.busy, profileError: profileService.lastError,
                performance: profileService.supports("performance"), limitation: profileService.limitationText,
                profileWatcherPid: profileBackend.watcherProcessId,
                state: battery.state, time: battery.timeText, warning: battery.warningLevel,
                nativeReady: backend.nativeDevice.ready, recovery: backend.recovery, owner: backend.owner, watcherPid: backend.watcherProcessId,
                error: backend.lastError, tray: tray.items.values.map(item => item.id),
                panel: scene.coordinator.activeId, loaded: scene.panelHost.loaded,
                created: scene.createdCount, destroyed: scene.destroyedCount,
                screen: scene.panelHost.screen ? scene.panelHost.screen.name : "",
                depth: page && page.depth ? page.depth : 0,
                menu: level ? level.entries.map(entry => ({text: entry.text, enabled: entry.enabled, separator: entry.isSeparator,
                    children: entry.hasChildren, button: entry.buttonType, check: entry.checkState})) : [],
                focus: scene.Window.window && scene.Window.window.activeFocusItem ? scene.Window.window.activeFocusItem.objectName : ""
            });
        }
        function openMenu(index: int): void {
            const item = tray.items.values.find(item => item.id === "app" + index);
            window.scene.coordinator.openTray(item, window.scene.firstScreen, window.scene.bar.trayStrip.buttonFor(item));
        }
        function overflow(): void { window.scene.coordinator.open("trayOverflow", window.scene.firstScreen, null); }
        function profile(value: string): void { profileService.setProfile(value); }
        function activate(index: int, secondary: bool): void { window.scene.bar.trayActivationRequested(tray.items.values.find(item => item.id === "app" + index), secondary); }
        function focusItem(index: int): void { window.scene.bar.trayStrip.buttonFor(tray.items.values.find(item => item.id === "app" + index)).forceActiveFocus(); }
        function submenu(index: int): void {
            const page = window.scene.panelHost.window.page;
            const entry = page.currentLevel.entries[index];
            page.push(entry, entry.text);
        }
        function trigger(index: int): void {
            const page = window.scene.panelHost.window.page;
            page.currentLevel.activated(page.currentLevel.entries[index]);
        }
        function back(): void { window.scene.panelHost.window.page.back(); }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
