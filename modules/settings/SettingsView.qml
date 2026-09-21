pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var settings
    property var signalService: null
    property string section: "appearance"
    property real maximumHeight: Metrics.settingsHeight
    readonly property var page: content.item
    readonly property Item firstControl: page ? page.firstControl : null
    readonly property Item lastControl: page ? page.lastControl : null
    spacing: Metrics.space16
    signal requested(string surface)
    signal dismissed()
    signal ensureVisible(Item item)
    function focusInitial(reason = Qt.TabFocusReason): void { back.forceActiveFocus(reason); }
    function dismissOrCollapse(): void { if (section === "signal" && page) page.dismissOrCollapse(); else dismissed(); }

    UI.PanelText { width: parent.width; text: qsTr("Ustawienia"); font.bold: true }
    Row {
        width: parent.width
        spacing: Metrics.space12
        UI.NavigationButton {
            id: back
            objectName: "backButton"
            width: (parent.width - parent.spacing) / 2
            text: qsTr("Wstecz")
            rightTarget: close
            downTarget: appearance
            KeyNavigation.tab: close
            KeyNavigation.backtab: root.lastControl
            onClicked: root.requested("quickSettings")
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: close
            objectName: "closeButton"
            width: back.width
            text: qsTr("Zamknij")
            leftTarget: back
            downTarget: keyboard
            KeyNavigation.tab: appearance
            KeyNavigation.backtab: back
            onClicked: root.dismissed()
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    Row {
        width: parent.width
        spacing: Metrics.space12
        UI.NavigationButton {
            id: appearance
            objectName: "appearanceSection"
            width: (parent.width - parent.spacing * 2) / 3
            text: qsTr("Wygląd")
            checked: root.section === "appearance"
            rightTarget: keyboard
            upTarget: back
            downTarget: root.firstControl
            KeyNavigation.tab: keyboard
            KeyNavigation.backtab: close
            onClicked: root.section = "appearance"
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: keyboard
            objectName: "keyboardSection"
            width: appearance.width
            text: qsTr("Klawiatura")
            checked: root.section === "keyboard"
            leftTarget: appearance
            rightTarget: signalSection
            upTarget: close
            downTarget: root.firstControl
            KeyNavigation.tab: signalSection
            KeyNavigation.backtab: appearance
            onClicked: root.section = "keyboard"
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: signalSection
            objectName: "signalSection"
            width: appearance.width
            text: "Signal"
            checked: root.section === "signal"
            leftTarget: keyboard
            upTarget: close
            downTarget: root.firstControl
            KeyNavigation.tab: root.firstControl
            KeyNavigation.backtab: keyboard
            onClicked: root.section = "signal"
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    Loader {
        id: content
        width: parent.width
        sourceComponent: root.section === "appearance" ? appearancePage : root.section === "signal" ? signalPage : keyboardPage
    }
    Component {
        id: appearancePage
        AppearanceView {
            settings: root.settings
            upTarget: appearance
            onDismissed: root.dismissed()
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    Component {
        id: signalPage
        SignalSettings {
            service: root.signalService
            upTarget: signalSection
            onDismissed: root.dismissed()
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    Component {
        id: keyboardPage
        KeyboardView {
            settings: root.settings.keyboard
            maximumHeight: root.maximumHeight
            upTarget: keyboard
            onDismissed: root.dismissed()
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
}
