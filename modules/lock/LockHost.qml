pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property var service
    required property var state
    property url wallpaper: ""
    readonly property bool locked: state.locked
    readonly property bool secure: nativeLock.secure
    property int surfaceCount: 0
    signal failed(string message)
    function acquire(): bool { state.locked = true; return true; }
    function release(): void { state.locked = false; }
    WlSessionLock {
        id: nativeLock
        reloadableId: "putkin-session-lock"
        locked: root.state.locked
        onLockedChanged: {
            if (!locked && root.state.locked) {
                root.state.locked = false;
                root.failed(qsTr("Kompozytor odrzucił blokadę sesji."));
            }
        }
        WlSessionLockSurface {
            color: "#1e1e2e"
            LockView { anchors.fill: parent; service: root.service; wallpaper: root.wallpaper; date: clock.date }
            Component.onCompleted: ++root.surfaceCount
            Component.onDestruction: --root.surfaceCount
        }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes; enabled: root.locked }
}
