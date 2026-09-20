import QtQuick
import "../core"

Item {
    id: root
    default property alias contentData: column.data
    property alias spacing: column.spacing
    property bool shown: false
    readonly property alias fadePresentation: presentation
    implicitHeight: column.implicitHeight
    opacity: presentation.opacity
    visible: shown || opacity > 0
    enabled: shown
    // Leave room for a control's outer focus ring without scaling its pixels.
    // sourceRect on a same-sized layer would shrink the whole column to fit.
    readonly property Item composite: Item {
        id: composite
        parent: root
        readonly property real inset: Metrics.focusOffset + Metrics.focusWidth
        x: -inset; y: -inset
        width: root.width + inset * 2
        height: root.height + inset * 2
        layer.enabled: root.visible
        layer.live: root.shown
        Column {
            id: column
            x: composite.inset; y: x
            width: root.width
        }
    }
    FadePresentation { id: presentation; item: root; shown: root.shown }
}
