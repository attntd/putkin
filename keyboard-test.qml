// Native windows, keyboard IPC and storage in scripts/test-keyboard-wayland's
// private compositor. Hardware/session domains are explicitly mocked.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "preview"
import "modules/settings"
import "modules/messages"
import "modules/screenshot"
import "modules/quicksettings" as Panels

ShellRoot {
    id: root
    readonly property real generation: Date.now()
    function find(object: var, name: string): var {
        if (!object) return null;
        if (object.objectName === name) return object;
        for (const child of object.children || []) { const match = find(child, name); if (match) return match; }
        return null;
    }
    Component.onCompleted: { if (Quickshell.env("PUTKIN_KEYBOARD_TEST") !== "1") Qt.quit(); }
    SettingsFile { id: file }
    SettingsFile { id: keyboardFile; path: configHome + "/putkin/keyboard.json" }
    Settings { id: settings; storage: file; keyboard: keyboard }
    KeyboardBackend { id: keyboardBackend; shellPath: Quickshell.shellDir + "/keyboard-test.qml" }
    KeyboardSettings { id: keyboard; storage: keyboardFile; backend: keyboardBackend }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    HyprlandAppearanceBackend { id: windowAppearanceBackend }
    WindowAppearanceService { backend: windowAppearanceBackend }
    HyprlandService { id: hyprland }
    HyprlandActions { id: windowActions; service: hyprland }
    MockLauncherBackend { id: launcherBackend }
    LauncherService { id: launcher; backend: launcherBackend; workspaceService: hyprland; keyboard: keyboard; actions: actions }
    ScreenshotBackend { id: screenshotBackend }
    ScreenshotService { id: screenshot; backend: screenshotBackend; screens: Quickshell.screens }
    ScreenshotHost { id: screenshotHost; service: screenshot }
    MockAudioBackend { id: pipewire }
    AudioService { id: audio; backend: pipewire }
    MockBrightnessBackend { id: backlight }
    BrightnessService { id: brightness; backend: backlight }
    MockSessionBackend { id: sessionBackend }
    SessionService { id: sessionService; backend: sessionBackend }
    MockNotificationBackend { id: notificationBackend }
    NotificationService { id: notifications; backend: notificationBackend; screens: Quickshell.screens; monitorService: hyprland }
    BarFocus { id: barFocus; service: hyprland; screenNames: Quickshell.screens.map(screen => screen.name) }
    NotificationFocus { id: notificationFocus; service: notifications; panels: panels; barFocus: barFocus }
    PanelCoordinator { id: panels; screens: Quickshell.screens; monitorService: hyprland; barFocus: barFocus; settings: settings }
    PanelHost { id: host; coordinator: panels; loader: loader; launcher: launcher; audio: audio; brightness: brightness; notifications: notifications; sessionService: sessionService }
    LazyLoader { id: loader; component: host.surfaceId === "settings" ? settingsWindow : popupWindow }
    Component { id: settingsWindow; SettingsWindow { host: host } }
    Component { id: popupWindow; Panels.InteractivePanelWindow { host: host } }
    ActionController {
        id: actions
        coordinator: panels; launcher: launcher; hyprland: hyprland; windowActions: windowActions
        barFocus: barFocus; notificationFocus: notificationFocus; notifications: notifications
        audio: audio; brightness: brightness; sessionService: sessionService
        screenshot: screenshot
        messages: messagesController
    }
    ActionIpc { controller: actions }
    PanelIpc { coordinator: panels }
    SettingsFocus { coordinator: panels; service: hyprland; processId: Quickshell.processId }
    LauncherIpc { coordinator: panels; service: launcher }
    MockMessagingBackend { id: messagingBackend; Component.onCompleted: seed() }
    SignalService { id: messagingService; backend: messagingBackend }
    SignalMessagingAdapter { id: messagingAdapter; service: messagingService }
    MessageHub { id: messageHub; adapters: [messagingAdapter] }
    MessagesController { id: messagesController; hub: messageHub; screens: Quickshell.screens; monitorService: hyprland; loader: messagesLoader }
    LazyLoader { id: messagesLoader; MessagesWindow { controller: messagesController } }
    MessagesFocus { controller: messagesController; service: hyprland; processId: Quickshell.processId }
    FloatingWindow {
        id: target
        title: "Putkin keyboard target"
        implicitWidth: 400; implicitHeight: 220; visible: false
        color: Theme.backgroundStrong
        Text { anchors.centerIn: parent; color: Theme.text; text: "Okno testowe" }
    }
    Timer { interval: 300; running: hyprland.available; onTriggered: target.visible = true }
    FloatingWindow {
        id: navigationTarget
        title: "Putkin navigation target"
        implicitWidth: 400; implicitHeight: 220; visible: false
        color: Theme.backgroundStrong
    }
    IpcHandler {
        target: "probe"
        function navigationWindow(shown: bool): void { navigationTarget.visible = shown; }
        function closeMessages(): void { messagesController.close(); }
        function snapshot(): string {
            const page = root.find(host.window ? host.window.contentItem : null, "keyboardSection");
            const search = root.find(host.window ? host.window.contentItem : null, "launcherSearch");
            return JSON.stringify({generation: root.generation, ready: keyboard.ready && settings.ready && hyprland.available,
                active: panels.activeId, loaded: host.loaded, editing: settings.editing, saving: keyboard.saving,
                messagesLoaded: messagesController.loaded,
                keyboardBusy: keyboardBackend.current !== null || keyboardBackend.queue.length > 0,
                problem: keyboard.problem, actionError: actions.lastError, bindings: keyboard.persisted,
                color: settings.effective.accent, text: launcher.text, mode: launcher.chipMode,
                results: launcher.results.map(entry => ({id:entry.id, kind:entry.kind, action:entry.action})),
                captured: launcher.commandWindow ? launcher.commandWindow.address : "",
                screenshot: {phase: screenshot.phase, source: screenshot.imageSource, width: screenshot.imageWidth,
                    selectionReady: screenshotHost.selectionReady, previewReady: screenshotHost.previewReady,
                    height: screenshot.imageHeight, window: screenshot.windowAddress, selection: screenshot.selection,
                    saved: screenshot.savedPath, error: screenshot.lastError, busy: screenshotBackend.busy},
                settingsPage: !!page, searchFocus: search ? search.activeFocus : false});
        }
        function keyboardSection(): void { root.find(host.window.contentItem, "keyboardSection").click(); }
        function edit(action: string, shortcut: string, command: string): void {
            keyboard.setBinding(action, "shortcut", shortcut); keyboard.setBinding(action, "command", command);
        }
        function save(): bool { return keyboard.save(); }
        function capture(path: string): void {
            root.find(host.window.contentItem, "settingsSurface").grabToImage(result => result.saveToFile(path));
        }
        function color(value: string): void { settings.setColor("accent", value); }
        function saveColor(): bool { return settings.save(); }
        function query(value: string): void { launcher.edit(value); }
        function launcherFixture(): void {
            launcherBackend.applications = Array.from({length: 20}, (_, i) => ({id: "fixture-" + i, name: "Aplikacja " + String(i).padStart(2, "0")}));
            launcherBackend.clipboard = [
                {id: "12", preview: "Tekst podglądu", binary: false, fullText: "Tekst podglądu\n\n" + "Zażółć gęślą jaźń.\n".repeat(80)},
                {id: "11", preview: "[[ binary data png 640x360 ]]", binary: true, image: Qt.resolvedUrl("tests/fixtures/launcher-preview.png").toString()}
            ];
        }
        function launcherSnapshot(): string {
            const window = host.window, content = window ? window.contentItem : null;
            const list = root.find(content, "launcherResults"), frame = root.find(content, "launcherPreview");
            const search = root.find(content, "launcherSearch"), resultsFade = root.find(content, "launcherResultsFade");
            const previewFade = root.find(content, "launcherPreviewFade");
            const image = root.find(frame, "launcherPreviewImage"), scroll = root.find(frame, "launcherPreviewScroll");
            const scrollbar = root.find(frame, "launcherPreviewScrollbar");
            const chip = root.find(content, "launcherChip");
            const rows = [];
            for (let i = 0; list && i < Math.min(list.count, 5); ++i) {
                const row = list.itemAtIndex(i);
                if (!row) continue;
                const subtitle = root.find(row, "launcherRowSubtitle"), icon = root.find(row, "launcherApplicationIcon");
                rows.push({action: row.modelData.action || "", category: subtitle.text, categoryVisible: subtitle.visible,
                    icon: icon.renderedSymbol, iconReady: icon.ready});
            }
            const surface = content ? content.children.find(child => child["viewport"] !== undefined) : null;
            function geometry(item) {
                if (!item) return null;
                const point = item.mapToItem(content, 0, 0);
                return {x: host.surfaceX + point.x, y: point.y, width: item.width, height: item.height};
            }
            const focus = content && content.Window.window ? content.Window.window.activeFocusItem : null;
            return JSON.stringify({active: panels.activeId, loaded: host.loaded, previewId: launcher.previewId,
                mode: launcher.mode, fieldText: search ? search.text : "", chipText: chip && chip.visible ? chip.text : "", rows: rows,
                text: launcher.previewText, imageReady: image ? image.status === Image.Ready : false,
                focus: focus ? focus.objectName : "", search: geometry(search), list: geometry(list), frame: geometry(frame),
                surface: geometry(surface), primaryHeight: surface ? surface.primaryHeight : 0,
                opacity: surface ? surface.opacity : 0,
                resultsOpacity: resultsFade ? resultsFade.opacity : 0, resultsCurrent: resultsFade ? resultsFade.current : false,
                resultCount: list ? list.count : 0, listContentY: list ? list.contentY : 0,
                selectedIndex: surface && surface.page ? surface.page.selectedIndex : -1,
                previewOpacity: previewFade ? previewFade.opacity : 0, previewCurrent: previewFade ? previewFade.current : false,
                displayedPreviewId: previewFade && previewFade.displayedValue ? previewFade.displayedValue.id : "",
                previewScrollbar: geometry(scrollbar), previewScrollSize: scrollbar ? scrollbar.size : 1,
                contentY: scroll ? scroll.contentY : 0, activations: launcherBackend.activations.length});
        }
        function activate(): bool { return launcher.activate(launcher.results[0]); }
        function reload(): void { Quickshell.reload(true); }
        function softReload(): void { Quickshell.reload(false); }
    }
}
