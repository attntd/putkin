pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

UI.FadeScope {
    id: root
    required property var request
    property bool interactive: request !== null && !request.done
    readonly property bool accentScope: true
    readonly property alias passwordField: field
    property int successFrames: 0
    readonly property bool paintingSuccess: request !== null && request.done
        && request.fingerprintState === "success" && successFrames < 2
    implicitWidth: 420
    implicitHeight: content.implicitHeight + 2 * Metrics.space16
    enabled: interactive
    shown: interactive || paintingSuccess
    contentKey: request

    function clear(): void { field.clear(); }
    function ensureVisible(item: Item): void {
        const flick = scroll.contentItem as Flickable;
        if (!flick || !item || !interactive) return;
        const y = item.mapToItem(content, 0, 0).y;
        flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height),
            y < flick.contentY ? y : y + item.height > flick.contentY + flick.height ? y + item.height - flick.height : flick.contentY));
    }
    function focusInitial(): void {
        if (!interactive || !request) return;
        if (request.mode === "input" && request.responseRequired)
            field.forceActiveFocus(request.fingerprintProgress > 0 ? Qt.TabFocusReason : Qt.OtherFocusReason);
        else if (cancel.visible) cancel.forceActiveFocus(Qt.OtherFocusReason);
        else accept.forceActiveFocus(Qt.OtherFocusReason);
    }
    function submit(): void {
        if (!interactive || !request || !request.responseRequired) return;
        const response = field.text;
        field.clear();
        request.submit(response);
    }
    function navigate(event: var): void {
        if (!interactive || field.activeFocus) return;
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
        const items = [identity, field, cancel, reject, accept].filter(item => item.visible && item.enabled);
        const index = items.findIndex(item => item.activeFocus);
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && index >= 0 && items[index] !== field) {
            if (!event.isAutoRepeat) items[index].click();
            event.accepted = true; return;
        }
        let step = 0;
        if ([Qt.Key_H, Qt.Key_K, Qt.Key_Left, Qt.Key_Up].indexOf(event.key) >= 0) step = -1;
        if ([Qt.Key_J, Qt.Key_L, Qt.Key_Right, Qt.Key_Down].indexOf(event.key) >= 0) step = 1;
        if (step && items.length) { items[(index + step + items.length) % items.length].forceActiveFocus(Qt.TabFocusReason); event.accepted = true; }
    }
    onRequestChanged: { successFrames = 0; clear(); Qt.callLater(focusInitial); }
    onInteractiveChanged: { clear(); if (interactive) Qt.callLater(focusInitial); else focus = false; }
    Window.onActiveChanged: { if (Window.active) Qt.callLater(focusInitial); }
    Keys.priority: Keys.AfterItem
    Keys.onPressed: event => navigate(event)
    Keys.onEscapePressed: { if (request && interactive) request.cancel(); }
    Connections {
        target: root.request
        function onResponseRequiredChanged(): void {
            root.clear();
            if (root.request && root.request.responseRequired) Qt.callLater(root.focusInitial);
            else root.forceActiveFocus(Qt.OtherFocusReason);
        }
        function onIdentityIndexChanged(): void { root.clear(); }
    }
    // Publish the confirmed green glyph into the shared fade layer before
    // freezing its exit frame. Authorization and keyboard release are immediate.
    FrameAnimation { running: root.paintingSuccess; onTriggered: root.successFrames++ }
    Rectangle { anchors.fill: parent; color: Theme.backgroundStrong; border.color: Theme.border; border.width: Metrics.borderWidth }
    Controls.ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: Metrics.space16
        contentWidth: availableWidth
        clip: true
        Column {
            id: content
            width: parent.width
            spacing: Metrics.space12
            UI.PanelText { width: parent.width; text: root.request ? root.request.title : ""; font.bold: true; textFormat: Text.PlainText }
            UI.PanelText {
                width: parent.width
                text: root.request ? root.request.context : ""
                visible: text.length > 0
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
            }
            UI.Button {
                id: identity
                objectName: "authIdentity"
                width: parent.width
                visible: root.request !== null && root.request.identities.length > 1
                text: visible ? root.request.identities[root.request.identityIndex] : ""
                onClicked: root.request.selectIdentity((root.request.identityIndex + 1) % root.request.identities.length)
                onActiveFocusChanged: { if (activeFocus) root.ensureVisible(identity); }
            }
            UI.PanelText {
                width: parent.width
                visible: root.request !== null && root.request.identities.length === 1
                text: visible ? root.request.identities[0] : ""
                textFormat: Text.PlainText
            }
            Item {
                id: inputSlot
                objectName: "authInputSlot"
                width: parent.width
                height: Metrics.controlHeight
                visible: root.request !== null && (root.request.fingerprintState !== "hidden"
                    || (root.request.mode === "input" && (root.request.responseRequired || root.request.fingerprintProgress > 0)))
                Rectangle {
                    id: progressTrack
                    objectName: "authCountdown"
                    anchors.fill: parent
                    visible: !field.visible
                    color: Theme.background
                    border.color: Theme.border
                    border.width: Metrics.borderWidth
                    UI.AccentRectangle {
                        objectName: "authCountdownFill"
                        x: Metrics.borderWidth; y: Metrics.borderWidth
                        width: Math.max(0, fingerprint.x - Metrics.space8 - x)
                            * (root.request ? root.request.fingerprintProgress : 0)
                        height: parent.height - 2 * Metrics.borderWidth
                        color: "transparent"
                        accentFill: true
                    }
                }
                UI.TextField {
                    id: field
                    objectName: "authPassword"
                    anchors.fill: parent
                    rightPadding: fingerprint.visible ? fingerprint.width + 2 * Metrics.space8 : Metrics.space8
                    visible: root.request !== null && root.request.mode === "input" && root.request.responseRequired
                    placeholderText: root.request ? root.request.prompt : ""
                    echoMode: root.request && root.request.responseVisible ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    maximumLength: 4096
                    invalid: root.request !== null && root.request.invalid
                    onAccepted: root.submit()
                    onEnsureVisible: item => root.ensureVisible(item)
                    KeyNavigation.tab: cancel.visible ? cancel : accept
                    KeyNavigation.backtab: identity.visible ? identity : accept
                }
                UI.Glyph {
                    id: fingerprint
                    objectName: "authFingerprint"
                    visible: root.request !== null && root.request.fingerprintState !== "hidden"
                    symbol: "fingerprint"
                    section: "list"
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.space8
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.request && root.request.fingerprintState === "success" ? Theme.success
                        : root.request && root.request.fingerprintState === "error" ? Theme.error : Theme.textMuted
                }
            }
            UI.PanelText {
                objectName: "authError"
                width: parent.width
                visible: text.length > 0
                text: root.request ? root.request.errorText : ""
                color: Theme.error
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
            }
            Flow {
                width: parent.width
                spacing: Metrics.space8
                UI.Button {
                    id: cancel
                    objectName: "authCancel"
                    text: qsTr("Anuluj")
                    visible: !root.request || root.request.mode !== "message"
                    onClicked: root.request.cancel()
                    onActiveFocusChanged: { if (activeFocus) root.ensureVisible(cancel); }
                    KeyNavigation.tab: reject.visible ? reject : accept.visible && accept.enabled ? accept : field.visible ? field : cancel
                    KeyNavigation.backtab: field.visible ? field : identity.visible ? identity : accept
                }
                UI.Button {
                    id: reject
                    objectName: "authReject"
                    text: root.request ? root.request.rejectText : ""
                    visible: text.length > 0 && root.request.mode === "confirm"
                    onClicked: root.request.reject()
                    onActiveFocusChanged: { if (activeFocus) root.ensureVisible(reject); }
                    KeyNavigation.tab: accept
                    KeyNavigation.backtab: cancel
                }
                UI.Button {
                    id: accept
                    objectName: "authAccept"
                    text: root.request ? root.request.acceptText : ""
                    visible: root.request !== null && root.request.mode !== "touch"
                    enabled: root.request !== null && root.request.responseRequired
                    onClicked: root.submit()
                    onActiveFocusChanged: { if (activeFocus) root.ensureVisible(accept); }
                    KeyNavigation.tab: field.visible ? field : cancel
                    KeyNavigation.backtab: reject.visible ? reject : cancel
                }
            }
        }
    }
    Component.onCompleted: Qt.callLater(focusInitial)
    Component.onDestruction: clear()
}
