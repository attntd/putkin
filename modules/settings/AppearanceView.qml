import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var settings
    spacing: Metrics.space16
    signal dismissed()
    signal ensureVisible(Item item)
    property Item upTarget: null
    readonly property Item firstControl: primary.firstControl
    readonly property Item lastControl: cancel
    function focusInitial(): void { primary.firstControl.forceActiveFocus(Qt.TabFocusReason); }
    function dismissOrCollapse(): void { dismissed(); }

    ColorEditor {
        id: primary
        width: parent.width
        settings: root.settings
        colorKey: "accent"
        title: qsTr("Akcent główny")
        enabled: root.settings.ready && !root.settings.saving
        upTarget: root.upTarget
        downTarget: secondary.firstControl
        onEnsureVisible: item => root.ensureVisible(item)
    }
    ColorEditor {
        id: secondary
        width: parent.width
        settings: root.settings
        colorKey: "accentSecondary"
        title: qsTr("Akcent dodatkowy")
        enabled: primary.enabled
        upTarget: primary.field
        downTarget: reset
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.NavigationButton {
        id: reset
        objectName: "resetButton"
        width: parent.width
        text: qsTr("Przywróć domyślne")
        enabled: primary.enabled
        upTarget: secondary.field
        downTarget: reload.visible ? reload : save.enabled ? save : cancel
        KeyNavigation.tab: reload.visible ? reload : save
        KeyNavigation.backtab: secondary.field
        onClicked: root.settings.resetDraft()
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.NavigationButton {
        id: reload
        objectName: "reloadSettingsButton"
        width: parent.width
        visible: root.settings.conflict || root.settings.readProblem.length > 0
        enabled: !root.settings.saving
        text: qsTr("Wczytaj ponownie")
        upTarget: reset
        downTarget: save.enabled ? save : cancel
        KeyNavigation.tab: save
        KeyNavigation.backtab: reset
        onClicked: { const reason = focusReason; root.settings.useLatest(); reset.forceActiveFocus(reason); }
        onEnsureVisible: item => root.ensureVisible(item)
    }
    Row {
        width: parent.width
        spacing: Metrics.space12
        UI.NavigationButton {
            id: save
            objectName: "saveSettingsButton"
            width: (parent.width - parent.spacing) / 2
            text: qsTr("Zapisz")
            highlighted: true
            enabled: root.settings.canSave
            rightTarget: cancel
            upTarget: reload.visible ? reload : reset
            KeyNavigation.tab: cancel
            KeyNavigation.backtab: reload.visible ? reload : reset
            onClicked: root.settings.save()
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: cancel
            objectName: "cancelSettingsButton"
            width: save.width
            text: qsTr("Anuluj")
            leftTarget: save
            upTarget: reload.visible ? reload : reset
            KeyNavigation.tab: root.upTarget
            KeyNavigation.backtab: save
            onClicked: root.dismissed()
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
}
