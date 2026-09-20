import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var brightness
    required property string monitor
    required property Item previousControl
    required property Item nextControl
    property bool expanded: false
    property bool hadSliderFocus: false
    readonly property Item firstControl: brightness.available ? slider : details
    readonly property Item lastControl: expanded ? refresh : brightness.available ? slider : details
    signal ensureVisible(Item item)
    spacing: Metrics.space8

    function restore(): void { slider.value = Math.max(1, Math.min(100, brightness.requestedPercent)); }
    function collapse(): bool {
        if (!expanded) return false;
        expanded = false;
        details.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }
    function recoverFocus(): void {
        const current = root.Window.window ? root.Window.window.activeFocusItem : null;
        if (hadSliderFocus && (!current || !current.enabled || !current.visible || !current.activeFocusOnTab))
            details.forceActiveFocus(Qt.TabFocusReason);
    }
    Item {
        id: brightnessRow
        objectName: "brightnessRow"
        width: parent.width
        height: Metrics.controlHeight
        Row {
            width: parent.width
            spacing: Metrics.space4
            UI.NavigationButton {
                id: details
                objectName: "brightnessDetails"
                width: Metrics.controlHeight
                padding: 0
                text: qsTr("Jasność")
                rightTarget: slider.enabled ? slider : root.nextControl
                upTarget: root.previousControl
                downTarget: root.expanded ? refresh : root.nextControl
                KeyNavigation.tab: slider.enabled ? slider : downTarget
                KeyNavigation.backtab: root.previousControl
                onClicked: root.expanded = !root.expanded
                onEnsureVisible: item => { root.hadSliderFocus = false; root.ensureVisible(item); }
                contentItem: UI.Glyph { section: "slider"; symbol: "brightness_6"; color: Theme.text }
                background: Rectangle { color: details.hovered ? Theme.surface : "transparent" }
            }
            UI.Slider {
                id: slider
                objectName: "brightnessSlider"
                width: Math.max(32, parent.width - details.width - valueLabel.width - parent.spacing * 3 - Metrics.controlHeight)
                enabled: root.brightness.available
                drawFocus: false
                accessibleName: qsTr("Jasność podświetlenia")
                fillColor: Theme.accentSecondary
                from: 1; to: 100
                stepSize: root.brightness.available ? Math.max(5, 100 / root.brightness.sample.maximum) : 5
                value: Math.max(1, Math.min(100, root.brightness.requestedPercent))
                onMoved: { if (!root.brightness.setPercent(value, root.monitor)) root.restore(); }
                onPressedChanged: { if (!pressed && !root.brightness.busy) root.restore(); }
                onActiveFocusChanged: { if (activeFocus) { root.hadSliderFocus = true; root.ensureVisible(slider); } }
                KeyNavigation.up: root.previousControl
                KeyNavigation.down: root.expanded ? refresh : root.nextControl
                KeyNavigation.tab: root.expanded ? refresh : root.nextControl
                KeyNavigation.backtab: details
                Keys.onPressed: event => {
                    if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
                    if (event.key === Qt.Key_H || event.key === Qt.Key_L)
                        root.brightness.change(event.key === Qt.Key_H ? -stepSize : stepSize, root.monitor);
                    else if (event.key === Qt.Key_J) (root.expanded ? refresh : root.nextControl).forceActiveFocus(Qt.TabFocusReason);
                    else if (event.key === Qt.Key_K) root.previousControl.forceActiveFocus(Qt.TabFocusReason);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (!event.isAutoRepeat) root.brightness.setPercent(value, root.monitor);
                    } else return;
                    event.accepted = true;
                }
            }
            UI.PanelText {
                id: valueLabel
                objectName: "brightnessStatus"
                width: 40; height: Metrics.controlHeight
                horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                text: root.brightness.available ? Math.round(root.brightness.percent) + "%" : "—"
            }
        }
        UI.FocusIndicator { control: slider.activeFocus ? slider : details }
    }
    UI.FadeColumn {
        width: parent.width
        shown: root.expanded
        UI.NavigationButton {
            id: refresh
            objectName: "brightnessRefresh"
            width: parent.width
            text: qsTr("Odśwież")
            upTarget: details
            downTarget: root.nextControl
            KeyNavigation.tab: downTarget
            KeyNavigation.backtab: details
            onClicked: root.brightness.refresh()
            onEnsureVisible: item => { root.hadSliderFocus = false; root.ensureVisible(item); }
        }
    }
    Connections {
        target: root.brightness
        function onRequestedPercentChanged(): void { if (!slider.pressed) root.restore(); }
        function onBusyChanged(): void { if (!root.brightness.busy && !slider.pressed) root.restore(); }
        function onAvailableChanged(): void { if (!root.brightness.available) Qt.callLater(root.recoverFocus); }
    }
}
