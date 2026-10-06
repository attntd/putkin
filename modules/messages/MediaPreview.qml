pragma ComponentBehavior: Bound
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
    property int focusReason: initialFocusReason
    component OverlayButton: UI.NavigationButton {
        tooltip: ""
        onFocusReasonChanged: if (activeFocus) root.focusReason = focusReason
        onActiveFocusChanged: if (activeFocus) root.focusReason = focusReason
    }
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
    readonly property bool photo: /^image\//.test(attachment.content_type)
    readonly property bool movie: /^(audio|video)\//.test(attachment.content_type) || attachment.content_type === "application/ogg"
    readonly property string imageSource: photo && !attachment.errorCode ? attachment.url || attachment.preview || "" : ""
    readonly property bool decoderFailed: !!attachment.errorCode || player.error !== MediaPlayer.NoError || image.status === Image.Error
    readonly property string playbackError: decoderFailed || (!movie && !imageSource) ? qsTr("Podgląd niedostępny") : ""
    readonly property bool controlsRevealed: !photo || hover.hovered || close.visualFocus || save.visualFocus
    opacity: 0
    enabled: !closing
    Behavior on opacity { NumberAnimation { duration: Metrics.panelFade; easing.type: Easing.InOutQuad } }
    Timer { id: closeDelay; interval: Metrics.panelFade; onTriggered: root.dismissed(root.dismissReason) }
    onFocusReasonChanged: if (focusReason === Qt.MouseFocusReason) {
        close.focusReason = focusReason; save.focusReason = focusReason;
        play.focusReason = focusReason; external.focusReason = focusReason;
    }
    Rectangle { anchors.fill: parent; color: Theme.backgroundStrong }
    MouseArea { anchors.fill: parent; onPressed: root.focusReason = Qt.MouseFocusReason }
    HoverHandler { id: hover }
    Image {
        id: image
        objectName: "attachmentImage"
        anchors.fill: parent
        source: root.imageSource
        asynchronous: true
        cache: false
        autoTransform: true
        mipmap: true
        retainWhileLoading: true
        sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
        fillMode: Image.PreserveAspectFit
        visible: root.photo
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
    Item {
        id: overlay
        objectName: "mediaOverlay"
        anchors.centerIn: parent
        width: root.photo && image.status === Image.Ready
            ? Math.min(root.width, Math.max(image.paintedWidth, controls.implicitWidth + 2 * Metrics.space12)) : root.width
        height: root.photo && image.status === Image.Ready ? image.paintedHeight : root.height
        opacity: root.controlsRevealed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Metrics.panelFade; easing.type: Easing.InOutQuad } }
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: metadata.implicitHeight + 2 * Metrics.space12
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, .7) }
                GradientStop { position: 1; color: "transparent" }
            }
            RowLayout {
                id: metadata
                anchors.fill: parent
                anchors.margins: Metrics.space12
                spacing: Metrics.space8
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
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: controls.implicitHeight + 2 * Metrics.space12
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, .7) }
            }
            RowLayout {
                id: controls
                anchors.fill: parent
                anchors.margins: Metrics.space12
                spacing: Metrics.space8
                OverlayButton {
                    id: play
                    objectName: "playMedia"
                    visible: root.movie
                    text: player.playbackState === MediaPlayer.PlayingState ? qsTr("Pauza") : qsTr("Odtwórz")
                    enabled: !root.decoderFailed && player.mediaStatus !== MediaPlayer.LoadingMedia
                    rightTarget: save
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
                OverlayButton {
                    id: save
                    objectName: "saveMedia"
                    text: qsTr("Zapisz")
                    leftTarget: root.movie ? play : close
                    rightTarget: root.photo ? close : external
                    KeyNavigation.tab: rightTarget
                    KeyNavigation.backtab: leftTarget
                    onClicked: destination.open()
                }
                OverlayButton {
                    id: external
                    objectName: "openMedia"
                    visible: !root.photo
                    text: qsTr("Otwórz")
                    leftTarget: save
                    rightTarget: close
                    KeyNavigation.tab: close
                    KeyNavigation.backtab: save
                    onClicked: root.adapter.openAttachment(root.attachment.attachment_id)
                }
                OverlayButton {
                    id: close
                    objectName: "closeMediaPreview"
                    text: qsTr("Zamknij")
                    leftTarget: root.photo ? save : external
                    rightTarget: root.movie ? play : save
                    KeyNavigation.tab: rightTarget
                    KeyNavigation.backtab: leftTarget
                    onClicked: root.closePreview(close.focusReason)
                }
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
