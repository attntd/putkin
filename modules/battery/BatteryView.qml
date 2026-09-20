pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

// BatteryPopup's percentage, time, bar and profile choices in Putkin tokens.
Column {
    id: root
    required property var battery
    required property var powerProfiles
    property var controls: []
    property Item focusedProfile: null
    readonly property color levelColor: battery && battery.warningLevel === 2 ? Theme.error
        : battery && battery.warningLevel === 1 ? Theme.warning : Theme.accent
    spacing: Metrics.space12
    signal dismissed()
    signal requested(string surface)
    signal ensureVisible(Item item)

    function button(index: int): Item { return controls[index] || null; }
    function rebuildNavigation(): void {
        const items = [];
        for (let i = 0; i < choices.count; ++i) items.push(choices.itemAt(i));
        controls = items;
    }
    function focusInitial(reason = Qt.TabFocusReason): void {
        let first = null;
        for (let i = 0; i < choices.count; ++i) {
            const item = button(i);
            if (!item || !powerProfiles.supports(powerProfiles.choices[i].id)) continue;
            if (!first) first = item;
            if (powerProfiles.profile === powerProfiles.choices[i].id) { item.forceActiveFocus(reason); return; }
        }
        focusedProfile = null;
        (first || root).forceActiveFocus(reason);
    }
    function dismissOrCollapse(): void { dismissed(); }

    UI.PanelText {
        objectName: "batteryPercentage"
        width: parent.width
        text: root.battery ? root.battery.percentageText : "—"
        font.pixelSize: Metrics.batteryPercentageFontSize
        font.bold: true
    }
    Controls.ProgressBar {
        id: level
        objectName: "batteryLevel"
        width: parent.width
        height: Metrics.space12
        from: 0; to: 100
        value: root.battery && root.battery.percentage >= 0 ? root.battery.percentage : 0
        visible: root.battery !== null && root.battery.present
        Accessible.name: qsTr("Poziom baterii")
        Accessible.description: root.battery ? root.battery.percentageText : "—"
        background: Rectangle { color: Theme.surface }
        contentItem: Item {
            UI.AccentRectangle { width: parent.width * level.position; height: parent.height; color: root.levelColor; accentFill: !root.battery || root.battery.warningLevel === 0 }
        }
    }
    UI.PanelText {
        objectName: "batteryTime"
        width: parent.width
        visible: root.battery !== null && root.battery.present && (root.battery.charging || root.battery.state === 2)
        text: root.battery && root.battery.timeText ? root.battery.timeText : qsTr("Szacowanie czasu…")
        color: Theme.textMuted
    }
    Column {
        width: parent.width
        spacing: Metrics.space8
        Repeater {
            id: choices
            model: root.powerProfiles ? root.powerProfiles.choices : []
            onItemAdded: root.rebuildNavigation()
            onItemRemoved: root.rebuildNavigation()
            delegate: UI.NavigationButton {
                id: choice
                required property int index
                required property var modelData
                objectName: "batteryProfile-" + modelData.id
                width: parent.width
                verticalPadding: Metrics.space4
                enabled: root.powerProfiles.supports(modelData.id)
                checked: root.powerProfiles.profile === modelData.id
                text: modelData.title
                Accessible.description: root.powerProfiles.pendingProfile === modelData.id ? qsTr("Zmiana…") : checked ? qsTr("Aktywny") : ""
                upTarget: root.button((index + choices.count - 1) % choices.count)
                downTarget: root.button((index + 1) % choices.count)
                KeyNavigation.tab: downTarget
                KeyNavigation.backtab: upTarget
                onClicked: root.powerProfiles.setProfile(modelData.id)
                onEnsureVisible: item => root.ensureVisible(item)
                onActiveFocusChanged: { if (activeFocus) { root.focusedProfile = choice; root.ensureVisible(choice); } }
                onEnabledChanged: { if (!enabled && root.focusedProfile === choice) root.focusInitial(); }
                contentItem: RowLayout {
                    spacing: Metrics.space8
                    UI.Glyph {
                        symbol: choice.modelData.glyph; color: choice.foreground
                        Layout.preferredWidth: slotSize
                        Layout.fillHeight: true; Layout.minimumHeight: 0
                    }
                    Text {
                        text: choice.text; font: choice.font; color: choice.foreground
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    UI.PanelText {
        width: parent.width
        visible: text.length > 0
        text: root.powerProfiles ? root.powerProfiles.availabilityText : qsTr("Tryby pracy niedostępne")
        color: Theme.textMuted
    }
    UI.PanelText {
        width: parent.width
        visible: text.length > 0
        text: root.powerProfiles ? root.powerProfiles.limitationText : ""
        color: Theme.warning
    }
}
