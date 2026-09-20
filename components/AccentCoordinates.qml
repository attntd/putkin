import QtQuick
import "../core"

QtObject {
    id: root
    required property Item item
    // Read ancestor positions in the binding, including Flickable.contentItem.
    // The field follows layout/scroll changes without timers or per-frame work.
    function locate(target: var): var {
        if (!target) return {x: 0, y: 0, width: 1, height: 1};
        let node = target, x = 0, y = 0, scope = null;
        while (node) {
            if (node["accentScope"] === true)
                scope = {x: x, y: y, width: node.width, height: node.height};
            x += node.x; y += node.y;
            node = node.parent;
        }
        // A standalone card owns a field; inside a panel it shares that panel's.
        return scope || {x: 0, y: 0, width: target.width, height: target.height};
    }
    readonly property var bounds: locate(item)
    readonly property real x1: -bounds.x
    readonly property real y1: -bounds.y
    readonly property real groupWidth: Math.max(1, bounds.width)
    readonly property real groupHeight: Math.max(1, bounds.height)
    // Normalize both axes: opposite corners share the midpoint even for a bar.
    // LinearGradient projects onto this vector to yield (x/width + y/height)/2.
    readonly property real diagonalSquared: groupWidth * groupWidth + groupHeight * groupHeight
    readonly property real x2: x1 + 2 * groupWidth * groupHeight * groupHeight / diagonalSquared
    readonly property real y2: y1 + 2 * groupHeight * groupWidth * groupWidth / diagonalSquared
    readonly property real position: Math.max(0, Math.min(1,
        ((bounds.x + item.width / 2) / groupWidth + (bounds.y + item.height / 2) / groupHeight) / 2))
    readonly property color color: Theme.mix(Theme.accent, Theme.accentSecondary, position)
    readonly property color foreground: Theme.foreground(color)
}
