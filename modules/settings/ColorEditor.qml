pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../core/Appearance.js" as Appearance
import "../../components" as UI

Column {
    id: root
    required property var settings
    required property string colorKey
    required property string title
    property Item upTarget: null
    property Item downTarget: null
    property var buttons: []
    readonly property Item firstControl: buttons[0] || null
    readonly property alias field: input
    readonly property string value: settings.draft[colorKey]
    readonly property bool valid: Appearance.isHex(value)
    signal ensureVisible(Item item)
    spacing: Metrics.space8

    UI.PanelText { width: parent.width; text: root.title; font.bold: true }
    Grid {
        width: parent.width
        columns: 3
        spacing: Metrics.space8
        Repeater {
            model: Appearance.presets
            onItemAdded: (index, item) => {
                const items = root.buttons.slice();
                items[index] = item;
                root.buttons = items;
            }
            delegate: UI.NavigationButton {
                required property var modelData
                required property int index
                objectName: root.colorKey + "Preset" + index
                width: (root.width - Metrics.space8 * 2) / 3
                padding: Metrics.space4
                font.pixelSize: Metrics.smallFontSize
                checked: root.value.toLowerCase() === modelData.color
                text: modelData.name
                trailingIcon: checked ? "check" : ""
                Accessible.name: root.title + ": " + modelData.name
                foreground: Appearance.foreground(modelData.color)
                fillColor: modelData.color
                accentFill: false
                leftTarget: index % 3 > 0 ? root.buttons[index - 1] || null : null
                rightTarget: index % 3 < 2 ? root.buttons[index + 1] || null : null
                upTarget: index >= 3 ? root.buttons[index - 3] || null : root.upTarget
                downTarget: index < 3 ? root.buttons[index + 3] || null : input
                KeyNavigation.tab: index < 5 ? root.buttons[index + 1] || null : input
                KeyNavigation.backtab: index > 0 ? root.buttons[index - 1] || null : root.upTarget
                onClicked: root.settings.setColor(root.colorKey, modelData.color)
                onEnsureVisible: item => root.ensureVisible(item)
            }
        }
    }
    UI.TextField {
        id: input
        objectName: root.colorKey + "Field"
        width: parent.width
        text: root.value
        placeholderText: "#RRGGBB"
        Accessible.name: root.title + qsTr(" · kolor HEX")
        Accessible.description: invalid ? qsTr("Błąd: wpisz # i sześć cyfr szesnastkowych.") : qsTr("Kolor w formacie #RRGGBB")
        invalid: !root.valid
        KeyNavigation.tab: root.downTarget
        KeyNavigation.backtab: root.buttons[5] || null
        onTextEdited: root.settings.setColor(root.colorKey, text)
        function validate(): void { root.settings.validationProblem = root.valid ? "" : qsTr("Wpisz kolor w formacie #RRGGBB."); }
        onEditingFinished: validate()
        onAccepted: { validate(); if (root.valid && root.downTarget) root.downTarget.forceActiveFocus(Qt.TabFocusReason); }
        onEnsureVisible: item => root.ensureVisible(item)
    }
}
