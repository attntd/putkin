import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import "../../core"
import "../../components" as UI

FocusScope {
    id: root
    objectName: "mediaPreview"
    required property var attachment
    property var adapter
    signal dismissed(int reason)
    property int initialFocusReason: Qt.TabFocusReason
    property int dismissReason: Qt.TabFocusReason
    property bool closing: false
    function closePreview(reason: int): void { dismissReason = reason; closing = true; player.stop(); opacity = 0; closeDelay.start(); }
    readonly property Component soundFactory: Component { AudioOutput {} }
    function togglePlay(): void {
        if (player.playbackState === MediaPlayer.PlayingState) player.pause();
        else {
            if (player.hasAudio && !player.audioOutput) player.audioOutput = soundFactory.createObject(root);
            player.play();
        }
    }
    readonly property bool movie: /^(audio|video)\//.test(attachment.content_type) || attachment.content_type === "application/ogg"
    readonly property bool decoderFailed: !!attachment.errorCode || player.error !== MediaPlayer.NoError || image.status === Image.Error
    readonly property string playbackError: decoderFailed || (!movie && !attachment.preview) ? qsTr("Podgląd niedostępny") : ""
    opacity: 0
    enabled: !closing
    Behavior on opacity { NumberAnimation { duration: Metrics.panelFade; easing.type: Easing.InOutQuad } }
    Timer { id: closeDelay; interval: Metrics.panelFade; onTriggered: root.dismissed(root.dismissReason) }
    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundStrong
    }
    MouseArea { anchors.fill: parent }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.space12
        spacing: Metrics.space8
        RowLayout {
            Layout.fillWidth: true
            Text {
                objectName: "attachmentFilename"
                Layout.fillWidth: true
                text: root.attachment.filename
                elide: Text.ElideMiddle
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.fontSize
                textFormat: Text.PlainText
            }
            Text {
                objectName: "attachmentSize"
                text: (Number(root.attachment.size_bytes || 0) / 1024).toFixed(1) + " KiB"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.smallFontSize
                textFormat: Text.PlainText
            }
            UI.NavigationButton {
                id: close
                objectName: "closeMediaPreview"
                text: qsTr("Zamknij")
                downTarget: root.movie ? play : save
                KeyNavigation.tab: root.movie ? play : save
                KeyNavigation.backtab: external
                onClicked: root.closePreview(close.focusReason)
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Image {
                id: image
                anchors.fill: parent
                source: root.attachment.preview || ""
                asynchronous: true
                cache: false
                sourceSize: Qt.size(1600, 1600)
                fillMode: Image.PreserveAspectFit
                visible: !root.movie && !!root.attachment.preview
            }
            VideoOutput {
                id: video
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                visible: root.movie && !root.decoderFailed
            }
            Text {
                anchors.centerIn: parent
                width: parent.width
                text: root.playbackError
                visible: root.playbackError !== ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.fontSize
            }
        }
        RowLayout {
            Layout.fillWidth: true
            UI.NavigationButton {
                id: play
                objectName: "playMedia"
                visible: root.movie
                text: player.playbackState === MediaPlayer.PlayingState ? qsTr("Pauza") : qsTr("Odtwórz")
                enabled: !root.decoderFailed && player.mediaStatus !== MediaPlayer.LoadingMedia
                upTarget: close
                rightTarget: external
                KeyNavigation.tab: save
                KeyNavigation.backtab: close
                onClicked: root.togglePlay()
            }
            Text {
                visible: root.movie && !root.decoderFailed
                text: Math.floor(player.position / 1000) + " / " + Math.floor(player.duration / 1000) + " s"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.smallFontSize
            }
            Item { Layout.fillWidth: true }
            UI.NavigationButton {
                id: save
                objectName: "saveMedia"
                text: qsTr("Zapisz")
                leftTarget: play
                rightTarget: external
                upTarget: close
                KeyNavigation.tab: external
                KeyNavigation.backtab: root.movie ? play : close
                onClicked: destination.open()
            }
            UI.NavigationButton {
                id: external
                objectName: "openMedia"
                text: qsTr("Otwórz")
                leftTarget: save
                upTarget: close
                KeyNavigation.tab: close
                KeyNavigation.backtab: save
                onClicked: root.adapter.openAttachment(root.attachment.attachment_id)
            }
        }
    }
    MediaPlayer {
        id: player
        objectName: "attachmentPlayer"
        source: root.movie ? root.attachment.url : ""
        videoOutput: video
        autoPlay: false
    }
    FileDialog {
        id: destination
        fileMode: FileDialog.SaveFile
        onAccepted: root.adapter.saveAttachment(root.attachment.attachment_id, selectedFile.toString())
    }
    Keys.onEscapePressed: closePreview(Qt.TabFocusReason)
    Component.onCompleted: { Qt.callLater(() => { opacity = 1; close.forceActiveFocus(initialFocusReason); }); }
    Component.onDestruction: player.stop()
}
