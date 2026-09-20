import QtQuick
import "../core"

QtObject {
    id: root
    required property Item item
    required property bool shown
    property bool ready: true
    property var contentKey: null
    property bool completed: false
    property bool prepared: false
    property rect previousGeometry: Qt.rect(0, 0, 0, 0)
    property int stableFrames: 0
    readonly property var window: item.Window.window
    readonly property var enclosing: findEnclosing(item.parent)
    readonly property bool enteringTogether: enclosing !== null && enclosing.shown && enclosing.opacity < 1
    property real opacity: shown && ready && (prepared || enteringTogether) ? 1 : 0

    function findEnclosing(parent: var): var {
        for (let node = parent; node; node = node.parent)
            if (node["fadePresentation"] !== undefined) return node["fadePresentation"];
        return null;
    }
    function invalidate(): void {
        prepared = false;
        stableFrames = 0;
    }
    onReadyChanged: { if (!ready) invalidate(); }
    onContentKeyChanged: invalidate()
    onShownChanged: { if (!shown && opacity === 0) invalidate(); }
    onOpacityChanged: { if (!shown && opacity === 0) invalidate(); }

    Behavior on opacity {
        enabled: root.prepared && !root.enteringTogether
        NumberAnimation { duration: Metrics.panelFade; easing.type: Easing.InOutCubic }
    }
    // Run only while opening. Two unchanged frame updates let positioners,
    // the window size and the shared gradient settle before revealing content.
    readonly property FrameAnimation preparation: FrameAnimation {
        running: root.completed && root.shown && root.ready && !root.prepared
            && root.window !== null && root.window.visible && root.item.width > 0 && root.item.height > 0
        onTriggered: {
            const origin = root.item.mapToItem(null, 0, 0);
            const geometry = Qt.rect(origin.x, origin.y, root.item.width, root.item.height);
            if (geometry === root.previousGeometry) root.stableFrames++;
            else { root.previousGeometry = geometry; root.stableFrames = 0; }
            if (root.stableFrames >= 2) root.prepared = true;
        }
    }
    Component.onCompleted: completed = true
}
