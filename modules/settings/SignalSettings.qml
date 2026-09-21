import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var service
    property Item upTarget: null
    readonly property Item firstControl: deviceName.enabled ? deviceName : primary
    readonly property Item lastControl: confirmDelete ? deleteHistory : remove.visible ? remove : toolsVisible ? save : tools
    property bool toolsVisible: false
    property bool confirmDelete: false
    readonly property bool pairing: service && (service.linkAttempt !== "" || service.reconciling)
    readonly property bool linked: service && service.accountState === "linked"
    spacing: Metrics.space12
    signal ensureVisible(Item item)
    signal dismissed()
    function focusInitial(reason = Qt.TabFocusReason): void { deviceName.forceActiveFocus(reason); }
    function dismissOrCollapse(): void {
        if (confirmDelete) { confirmDelete = false; remove.forceActiveFocus(Qt.TabFocusReason); }
        else if (service && service.linkAttempt) service.cancelLink();
        else dismissed();
    }
    Component.onCompleted: { if (service && service.ready) service.refreshAccount(); }
    Component.onDestruction: { if (service && service.linkAttempt) service.cancelLink(); }

    UI.PanelText { objectName: "signalStatus"; width: parent.width; text: root.service ? root.service.statusText : qsTr("Niedostępny") }
    UI.PanelText { width: parent.width; text: qsTr("Nazwa urządzenia") }
    UI.TextField {
        id: deviceName
        objectName: "signalDeviceName"
        width: parent.width
        text: root.service ? root.service.configuration.deviceName || "Putkin" : "Putkin"
        enabled: root.service !== null && !root.pairing && !root.linked
        maximumLength: 64
        Accessible.name: qsTr("Nazwa urządzenia")
        KeyNavigation.tab: primary
        KeyNavigation.backtab: root.upTarget
        Keys.onEscapePressed: root.upTarget.forceActiveFocus(Qt.TabFocusReason)
        onEnsureVisible: item => root.ensureVisible(item)
    }
    SignalQr {
        objectName: "signalQr"
        width: Math.min(parent.width, 280)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: modules.length > 0
        modules: root.service ? root.service.qrModules : []
    }
    UI.NavigationButton {
        id: primary
        objectName: "signalPrimary"
        width: parent.width
        highlighted: true
        enabled: root.service !== null && root.service.canManageAccount && !root.service.reconciling
            && (root.service.state !== "starting" || root.service.linkAttempt !== "")
        text: root.pairing ? qsTr("Anuluj parowanie")
            : root.service && root.service.state === "disabled" && root.linked ? qsTr("Włącz odbiór")
            : root.linked ? qsTr("Wyłącz odbiór")
            : root.service && root.service.accountState === "relinkRequired" ? qsTr("Połącz ponownie")
            : root.service && root.service.linkError === "link_expired" ? qsTr("Odnów kod") : qsTr("Połącz z telefonem")
        upTarget: deviceName.enabled ? deviceName : root.upTarget
        downTarget: refresh
        KeyNavigation.tab: refresh
        KeyNavigation.backtab: upTarget
        onClicked: {
            if (root.pairing) root.service.cancelLink();
            else if (root.linked) root.service.configure({enabled: root.service.state === "disabled"});
            else root.service.startLink(deviceName.text);
        }
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.NavigationButton {
        id: refresh
        objectName: "signalRefresh"
        width: parent.width
        text: qsTr("Sprawdź połączenie")
        enabled: root.service !== null && !root.pairing && root.service.state !== "starting"
        upTarget: primary
        downTarget: typing
        KeyNavigation.tab: typing
        KeyNavigation.backtab: primary
        onClicked: root.service.refreshAccount()
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.NavigationButton {
        id: typing
        objectName: "signalTyping"
        width: parent.width
        text: qsTr("Wskaźnik pisania w Putkinie")
        checked: root.service !== null && root.service.configuration.typingIndicators === true
        enabled: root.service !== null && !root.pairing
        upTarget: refresh
        downTarget: tools
        KeyNavigation.tab: tools
        KeyNavigation.backtab: refresh
        onClicked: root.service.configure({typingIndicators: !checked})
        onEnsureVisible: item => root.ensureVisible(item)
    }
    UI.NavigationButton {
        id: tools
        objectName: "signalTools"
        width: parent.width
        text: qsTr("Narzędzia")
        checked: root.toolsVisible
        enabled: root.service !== null && !root.pairing
        upTarget: typing
        downTarget: root.toolsVisible ? executable : remove.visible ? remove : root.upTarget
        KeyNavigation.tab: downTarget
        KeyNavigation.backtab: typing
        onClicked: root.toolsVisible = !root.toolsVisible
        onEnsureVisible: item => root.ensureVisible(item)
    }
    Column {
        visible: root.toolsVisible
        width: parent.width
        spacing: Metrics.space12
        UI.PanelText { text: "signal-cli" }
        UI.TextField {
            id: executable
            objectName: "signalExecutable"
            width: parent.width
            text: root.service ? root.service.configuration.executable || "signal-cli" : "signal-cli"
            Accessible.name: "signal-cli"
            KeyNavigation.backtab: tools
            KeyNavigation.tab: javaHome
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.PanelText { text: "Java" }
        UI.TextField {
            id: javaHome
            objectName: "signalJavaHome"
            width: parent.width
            text: root.service ? root.service.configuration.javaHome || "" : ""
            Accessible.name: "Java"
            KeyNavigation.backtab: executable
            KeyNavigation.tab: save
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: save
            objectName: "signalSaveTools"
            width: parent.width
            text: qsTr("Zapisz")
            enabled: root.service !== null && !root.pairing
            upTarget: javaHome
            downTarget: remove.visible ? remove : root.upTarget
            KeyNavigation.tab: downTarget
            KeyNavigation.backtab: javaHome
            onClicked: root.service.configure({executable: executable.text, javaHome: javaHome.text,
                deviceName: deviceName.text, enabled: true})
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    UI.NavigationButton {
        id: remove
        objectName: "signalRemoveHistory"
        width: parent.width
        visible: root.service !== null && root.service.accountId !== "" && root.service.state === "disabled"
        text: qsTr("Usuń lokalną historię Putkina")
        upTarget: root.toolsVisible ? save : tools
        downTarget: root.confirmDelete ? cancelDelete : root.upTarget
        KeyNavigation.tab: downTarget
        KeyNavigation.backtab: upTarget
        onClicked: { root.confirmDelete = true; cancelDelete.forceActiveFocus(Qt.TabFocusReason); }
        onEnsureVisible: item => root.ensureVisible(item)
    }
    Row {
        width: parent.width
        visible: root.confirmDelete && remove.visible
        spacing: Metrics.space12
        UI.NavigationButton {
            id: cancelDelete
            objectName: "signalCancelDelete"
            width: (parent.width - parent.spacing) / 2
            text: qsTr("Anuluj")
            upTarget: remove
            rightTarget: deleteHistory
            KeyNavigation.tab: deleteHistory
            KeyNavigation.backtab: remove
            onClicked: { root.confirmDelete = false; remove.forceActiveFocus(Qt.TabFocusReason); }
            onEnsureVisible: item => root.ensureVisible(item)
        }
        UI.NavigationButton {
            id: deleteHistory
            objectName: "signalConfirmDelete"
            width: cancelDelete.width
            text: qsTr("Usuń historię")
            upTarget: remove
            leftTarget: cancelDelete
            KeyNavigation.tab: root.upTarget
            KeyNavigation.backtab: cancelDelete
            onClicked: { root.service.clearHistory(); root.confirmDelete = false; remove.forceActiveFocus(Qt.TabFocusReason); }
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
}
