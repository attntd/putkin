import QtQuick
import QtQuick.Shapes

Rectangle {
    id: root
    property bool accentFill: false
    property bool accentOutline: false
    border.width: 0
    // Retain Rectangle's standard fill/border API and paint only accent roles.
    // The inner subpath leaves the existing background and content untouched.
    Shape {
        anchors.fill: parent
        visible: root.accentFill || root.accentOutline
        ShapePath {
            strokeWidth: -1
            // Qt 6.11's GPU renderer needs an opaque base to create fill geometry.
            // Software accepts transparent here, but then hides this GPU gradient.
            fillColor: root.accentFill ? "white" : "transparent"
            fillGradient: root.accentFill ? fill : null
            PathRectangle {
                x: root.border.width; y: root.border.width
                width: Math.max(0, root.width - 2 * root.border.width)
                height: Math.max(0, root.height - 2 * root.border.width)
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.accentOutline && root.border.width > 0 ? "white" : "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: root.accentOutline && root.border.width > 0 ? outline : null
            PathRectangle { width: root.width; height: root.height }
            PathRectangle {
                x: root.border.width; y: root.border.width
                width: Math.max(0, root.width - 2 * root.border.width)
                height: Math.max(0, root.height - 2 * root.border.width)
            }
        }
    }
    AccentGradient { id: fill; item: root }
    AccentGradient { id: outline; item: root; outline: true }
}
