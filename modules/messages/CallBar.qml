pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components" as UI

ColumnLayout {
    id: root
    required property var calls
    property Item downTarget: null
    readonly property var call: calls ? calls.current : null
    property real now: Date.now()
    readonly property Item firstAction: accept.visible ? accept : mute.visible ? mute : end
    property bool pendingFocus: false
    property int pendingFocusReason: Qt.OtherFocusReason
    visible: call !== null
    spacing: Metrics.space8
    function focusInitial(reason = Qt.TabFocusReason): void {
        if (accept.visible && accept.enabled) accept.forceActiveFocus(reason);
        else if (mute.visible && mute.enabled) mute.forceActiveFocus(reason);
        else end.forceActiveFocus(reason);
    }
    function restoreFocus(): void {
        if (!pendingFocus || !calls || calls.busy) return;
        pendingFocus = false;
        if (visible) focusInitial(pendingFocusReason);
    }
    Connections {
        target: root.calls
        function onBusyChanged(): void { Qt.callLater(root.restoreFocus); }
    }
    Timer {
        interval: 1000
        running: root.visible && root.call !== null && ["CONNECTED", "RECONNECTING"].includes(root.call.state)
        repeat: true
        onTriggered: root.now = Date.now()
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            objectName: "callTitle"
            text: root.call ? root.call.title : ""
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.fontSize
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            objectName: "callState"
            text: {
                if (!root.call) return "";
                const labels = {STARTING: qsTr("Łączenie"), RINGING_OUTGOING: qsTr("Dzwonię"), RINGING_INCOMING: qsTr("Połączenie przychodzące"),
                    CONNECTING: qsTr("Łączenie"), RECONNECTING: qsTr("Ponowne łączenie"), ENDED: qsTr("Zakończono")};
                if (root.call.state !== "CONNECTED") return labels[root.call.state] || "";
                const seconds = Math.max(0, Math.floor((root.now - root.call.connectedAtMs) / 1000));
                return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
            }
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.smallFontSize
        }
    }
    RowLayout {
        UI.NavigationButton {
            id: accept
            objectName: "acceptCall"
            visible: root.calls && root.calls.incoming
            enabled: visible && !root.calls.busy && !root.calls.blocked
            text: qsTr("Odbierz")
            tooltip: ""
            leadingIcon: "call"
            highlighted: true
            rightTarget: end
            downTarget: root.downTarget
            onClicked: {
                if (root.calls.accept()) {
                    root.pendingFocusReason = focusReason;
                    root.pendingFocus = true;
                    Qt.callLater(root.restoreFocus);
                }
            }
        }
        UI.NavigationButton {
            id: mute
            objectName: "muteCall"
            visible: root.call && ["CONNECTED", "RECONNECTING", "CONNECTING"].includes(root.call.state)
            enabled: visible && !root.calls.busy
            text: root.call && root.call.muted ? qsTr("Włącz mikrofon") : qsTr("Wycisz mikrofon")
            tooltip: ""
            Layout.preferredWidth: Metrics.controlHeight
            checked: root.call !== null && root.call.muted
            contentItem: UI.Glyph { symbol: mute.checked ? "mic_off" : "mic"; color: mute.foreground }
            rightTarget: end
            downTarget: root.downTarget
            onClicked: root.calls.mute()
        }
        UI.NavigationButton {
            id: end
            objectName: "endCall"
            text: !root.calls || !root.calls.active ? qsTr("Zamknij") : root.calls.incoming ? qsTr("Odrzuć") : qsTr("Rozłącz")
            tooltip: ""
            leadingIcon: root.calls && root.calls.active ? "call_end" : "close"
            enabled: root.call !== null && root.calls && !root.calls.busy && (!root.calls.active || root.call.callId !== "")
            leftTarget: accept.visible ? accept : mute
            downTarget: root.downTarget
            onClicked: {
                if (!root.calls.active) root.calls.dismiss();
                else if (root.calls.incoming) root.calls.reject();
                else root.calls.hangup();
            }
        }
        Item { Layout.fillWidth: true }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
}
