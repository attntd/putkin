pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    spacing: Metrics.space12
    property string description: qsTr("Ciemna paleta Mocha. Nieprzezroczyste powierzchnie, kwadratowe rogi i czytelny tekst monospace.")

    UI.PanelText { width: parent.width; text: root.description; color: Theme.textMuted }
    Repeater {
        model: [
            { label: qsTr("Akcent główny"), value: Theme.accent },
            { label: qsTr("Akcent dodatkowy"), value: Theme.accentSecondary },
            { label: qsTr("Tło · Base"), value: Theme.background }
        ]
        Row {
            required property var modelData
            width: root.width
            spacing: Metrics.space12
            Rectangle {
                width: Metrics.space24
                height: Metrics.space24
                color: parent.modelData.value
                border.color: Theme.border
                border.width: Metrics.borderWidth
            }
            UI.PanelText {
                width: Math.max(1, parent.width - Metrics.space24 - Metrics.space12)
                text: parent.modelData.label + "\n" + String(parent.modelData.value).toUpperCase()
                font.pixelSize: Metrics.smallFontSize
            }
        }
    }
    UI.PanelText {
        width: parent.width
        text: qsTr("Krój pisma: %1").arg(Theme.fontFamily)
        color: Theme.textMuted
        font.pixelSize: Metrics.smallFontSize
    }
}
