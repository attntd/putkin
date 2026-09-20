import QtQuick
import "../../core"
import "../../components" as UI

UI.FadeColumn {
    id: root
    required property var nightLight
    required property Item previousControl
    required property Item nextControl
    readonly property Item firstControl: slider
    readonly property Item lastControl: slider
    shown: nightLight.available && nightLight.enabled
    signal ensureVisible(Item item)
    function restore(): void { slider.value = Math.max(1000, Math.min(6500, nightLight.temperature || nightLight.preferredTemperature)); }

    Item {
        id: temperatureRow
        objectName: "nightLightTemperatureRow"
        width: parent.width
        height: Metrics.controlHeight
        Row {
            width: parent.width
            spacing: Metrics.space8
            UI.Glyph {
                objectName: "nightLightTemperatureIcon"
                section: "slider"
                width: Metrics.controlHeight
                height: Metrics.controlHeight
                symbol: "device_thermostat"
                color: Theme.text
            }
            UI.Slider {
                id: slider
                objectName: "nightLightTemperature"
                width: Math.max(32, parent.width - Metrics.controlHeight - valueLabel.width - parent.spacing * 2)
                visible: root.shown
                enabled: root.shown && !root.nightLight.busy
                drawFocus: false
                accessibleName: qsTr("Temperatura światła nocnego")
                from: 1000; to: 6500; stepSize: 100
                live: false
                value: Math.max(1000, Math.min(6500, root.nightLight.temperature || root.nightLight.preferredTemperature))
                onMoved: { if (!root.nightLight.setTemperature(value)) root.restore(); }
                onActiveFocusChanged: { if (activeFocus) root.ensureVisible(slider); }
                KeyNavigation.up: root.previousControl; KeyNavigation.down: root.nextControl
                KeyNavigation.tab: root.nextControl; KeyNavigation.backtab: root.previousControl
                Keys.onPressed: event => {
                    if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
                    if (event.key === Qt.Key_H || event.key === Qt.Key_L) {
                        root.nightLight.setTemperature(Math.max(from, Math.min(to, value + (event.key === Qt.Key_H ? -stepSize : stepSize))));
                    } else if (event.key === Qt.Key_J) root.nextControl.forceActiveFocus(Qt.TabFocusReason);
                    else if (event.key === Qt.Key_K) root.previousControl.forceActiveFocus(Qt.TabFocusReason);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (!event.isAutoRepeat) root.nightLight.setTemperature(value);
                    } else return;
                    event.accepted = true;
                }
            }
            UI.PanelText {
                id: valueLabel
                width: 52
                height: Metrics.controlHeight
                text: root.nightLight.temperature + " K"
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }
        UI.FocusIndicator { control: slider }
    }
    Connections { target: root.nightLight; function onRefreshed(): void { root.restore(); } }
}
