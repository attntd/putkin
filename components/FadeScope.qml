import QtQuick
import "../core"

FocusScope {
    id: root
    property bool shown: true
    property bool contentReady: true
    property var contentKey: null
    readonly property alias fadePresentation: presentation
    opacity: presentation.opacity
    visible: shown || opacity > 0
    // Composite the finished subtree once; individual translucent backgrounds
    // would otherwise show through icons, text and the shared accent gradient.
    layer.enabled: visible
    FadePresentation {
        id: presentation
        item: root
        shown: root.shown
        ready: root.contentReady
        contentKey: root.contentKey
    }
}
