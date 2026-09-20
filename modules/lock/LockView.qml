import QtQuick
import "../../core"
import "../../components" as UI

Item {
    id: root
    required property var service
    property url wallpaper: ""
    property date date: new Date()
    readonly property bool accentScope: true
    readonly property alias passwordField: password
    Rectangle { anchors.fill: parent; color: Theme.background }
    Image { anchors.fill: parent; source: root.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true }
    Rectangle { anchors.fill: parent; color: "#88181825" }
    Column {
        width: Math.min(360, Math.max(120, root.width - 32))
        anchors.centerIn: parent
        spacing: Metrics.space16
        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.date, "HH:mm")
            font.family: Theme.fontFamily
            font.pixelSize: Math.min(84, root.width / 6)
            color: clockAccent.color
            UI.AccentCoordinates { id: clockAccent; item: clockText }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.date, "dddd d MMMM")
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.text
        }
        UI.TextField {
            id: password
            objectName: "lockPassword"
            width: parent.width
            height: 44
            leftPadding: 44
            echoMode: TextInput.Password
            passwordCharacter: "●"
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            selectByMouse: false
            readOnly: root.service.passwordBusy || root.service.hold
            invalid: root.service.passwordFailed
            Accessible.name: qsTr("Hasło")
            Keys.onEscapePressed: event => { clear(); event.accepted = true; }
            onAccepted: {
                if (root.service.submit(text)) clear();
            }
            background: Rectangle {
                color: Theme.backgroundStrong
                border.width: Metrics.borderWidth
                border.color: password.invalid ? Theme.error : Theme.border
                UI.FocusIndicator { control: password; border.color: password.invalid ? Theme.error : Theme.focus }
            }
            Text {
                objectName: "lockFingerprint"
                x: 2; width: 40; height: parent.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: "\udb80\ude37"
                font.family: Theme.fontFamily; font.pixelSize: 22
                color: root.service.fingerprintState === "success" ? Theme.success
                    : root.service.fingerprintState === "error" ? Theme.error : Theme.textMuted
            }
            Component.onCompleted: forceActiveFocus(Qt.OtherFocusReason)
        }
    }
    Connections {
        target: root.service
        function onClearPassword(): void { password.clear(); }
    }
}
