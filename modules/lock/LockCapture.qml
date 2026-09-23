pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property var screens
    property bool capturing: false
    property var frames: []

    function clear(): void {
        deadline.stop();
        capturing = false;
        const old = frames;
        frames = [];
        for (const frame of old) {
            frame.visible = false;
            frame.parent = null;
            frame.captureSource = null;
            frame.destroy();
        }
    }
    function begin(): void {
        clear();
        capturing = true;
        deadline.start();
        for (const screen of screens) {
            const frame = frameComponent.createObject(captureWindow.contentItem, {captureSource: screen});
            frames = frames.concat([frame]);
        }
        Qt.callLater(checkReady);
    }
    function checkReady(): void {
        if (capturing && frames.every(frame => frame.hasContent || frame.finished)) finish();
    }
    function finish(): void {
        if (!capturing) return;
        deadline.stop();
        // A failed/slow capture never delays the native lock beyond the bound.
        // Cancel incomplete frames before locking so they cannot capture it.
        const discarded = frames.filter(frame => !frame.hasContent);
        frames = frames.filter(frame => frame.hasContent);
        for (const frame of discarded) { frame.captureSource = null; frame.destroy(); }
        capturing = false;
    }
    function attach(screen: var, parentItem: Item): var {
        const frame = frames.find(item => item.captureSource === screen && item.hasContent);
        if (!frame) return null;
        frame.parent = parentItem;
        frame.visible = true;
        return frame;
    }
    Timer { id: deadline; interval: 150; onTriggered: root.finish() }
    Component {
        id: frameComponent
        ScreencopyView {
            anchors.fill: parent
            visible: false
            live: false
            paintCursor: false
            property bool finished: false
            onHasContentChanged: { if (hasContent) Qt.callLater(root.checkReady); }
            onStopped: { finished = true; Qt.callLater(root.checkReady); }
        }
    }
    // An input-transparent, transparent pixel initializes Qt's capture buffer
    // manager. It never displays captured pixels or grabs keyboard focus.
    // Quickshell's runtime window factory is absent from its 0.3.1 metadata.
    // qmllint disable uncreatable-type
    PanelWindow {
        // qmllint enable uncreatable-type
        id: captureWindow
        visible: root.capturing && root.screens.length > 0
        screen: root.screens[0] || null
        anchors { top: true; left: true }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "putkin-lock-capture"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
    }
    Component.onDestruction: clear()
}
