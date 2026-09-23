pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

Scope {
    id: root
    required property var service
    required property var state
    required property var screens
    property url wallpaper: ""
    readonly property bool locked: state.locked
    readonly property bool secure: nativeLock.secure
    property var views: []
    readonly property int surfaceCount: views.length
    readonly property alias capture: desktopCapture
    signal failed(string message)
    function acquire(): bool {
        desktopCapture.begin();
        state.locked = true;
        return true;
    }
    function release(): void { state.locked = false; desktopCapture.clear(); }
    function finishUnlock(): void {
        if (service.unlocking && views.every(view => view.opacity === 0)) service.finishUnlock();
    }
    Connections {
        target: root.service
        function onUnlockingChanged(): void { Qt.callLater(root.finishUnlock); }
    }
    LockCapture { id: desktopCapture; screens: root.screens }
    WlSessionLock {
        id: nativeLock
        reloadableId: "putkin-session-lock"
        locked: root.state.locked && !desktopCapture.capturing
        onLockedChanged: {
            if (!locked && root.state.locked && !desktopCapture.capturing) {
                root.state.locked = false;
                desktopCapture.clear();
                root.failed(qsTr("Kompozytor odrzucił blokadę sesji."));
            }
        }
        WlSessionLockSurface {
            id: surface
            property var snapshot: null
            onScreenChanged: snapshot = desktopCapture.attach(screen, backdrop)
            // Session-lock surfaces stay opaque, including during the fade.
            color: Theme.background
            Item { id: backdrop; anchors.fill: parent }
            LockView {
                id: view
                anchors.fill: parent
                service: root.service
                animate: surface.snapshot !== null
                wallpaper: root.wallpaper
                date: clock.date
                onHidden: root.finishUnlock()
                Component.onCompleted: {
                    surface.snapshot = desktopCapture.attach(surface.screen, backdrop);
                    root.views = root.views.concat([view]);
                }
                Component.onDestruction: {
                    root.views = root.views.filter(item => item !== view);
                    Qt.callLater(root.finishUnlock);
                }
            }
        }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes; enabled: root.locked }
}
