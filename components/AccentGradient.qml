import QtQuick
import QtQuick.Shapes
import "../core"

LinearGradient {
    id: root
    required property Item item
    property bool outline: false
    readonly property AccentCoordinates coordinates: AccentCoordinates { item: root.item }
    x1: coordinates.x1; y1: coordinates.y1
    x2: coordinates.x2; y2: coordinates.y2
    GradientStop { position: 0; color: root.outline ? Theme.accentBorder : Theme.accent }
    GradientStop { position: 1; color: root.outline ? Theme.accentSecondaryBorder : Theme.accentSecondary }
}
