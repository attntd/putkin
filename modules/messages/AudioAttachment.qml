pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import "../../core"
import "../../components" as UI

Item {
    id: root
    objectName: "audioAttachment"
    required property var attachment
    required property string sizeLabel
    property color textColor: Theme.text
    property color mutedTextColor: Theme.textMuted
    property bool playbackEnabled: false
    property var audioOwner: null
    property Component soundFactory: Component { AudioOutput {} }
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property bool failed: player.error !== MediaPlayer.NoError
    readonly property alias mediaPlayer: player
    implicitHeight: attachment.voiceNote ? 56 : 76
    signal ensureVisible(Item item)
    function timeLabel(ms: real): string {
        const seconds = Math.floor(ms / 1000);
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
    function toggle(): void {
        if (!playbackEnabled) return;
        if (playing) { player.pause(); return; }
        if (audioOwner) audioOwner.audioAttachmentId = attachment.attachment_id;
        if (soundFactory && !player.audioOutput) player.audioOutput = soundFactory.createObject(root);
        player.source = attachment.url || "";
        player.play();
    }
    onPlaybackEnabledChanged: if (!playbackEnabled) player.stop()
    onVisibleChanged: if (!visible) player.stop()
    Connections {
        target: root.audioOwner
        function onAudioAttachmentIdChanged(): void {
            if (root.audioOwner.audioAttachmentId !== root.attachment.attachment_id) player.stop();
        }
    }
    MediaPlayer { id: player; objectName: "inlineAudioPlayer" }
    UI.NavigationButton {
        id: play
        objectName: "playAudioAttachment"
        x: 0; y: (parent.height - height) / 2
        width: 36; height: 36; padding: 6
        text: root.playing ? qsTr("Pauza") : qsTr("Odtwórz")
        tooltip: ""
        enabled: root.playbackEnabled
        rightTarget: seek
        foreground: root.textColor
        contentItem: UI.Glyph { symbol: root.playing ? "pause" : "play_arrow"; color: root.textColor }
        background: Rectangle {
            radius: width / 2
            color: root.textColor; opacity: play.down ? .3 : play.hovered ? .2 : .1
        }
        UI.FocusIndicator { control: play; border.color: root.textColor; accentOutline: false }
        onEnsureVisible: item => root.ensureVisible(item)
        onClicked: root.toggle()
    }
    Column {
        x: play.width + Metrics.space8
        width: Math.max(0, root.width - x)
        anchors.verticalCenter: parent.verticalCenter
        Text {
            objectName: "audioFilename"
            visible: !root.attachment.voiceNote
            width: parent.width
            text: root.attachment.filename || ""
            elide: Text.ElideMiddle; textFormat: Text.PlainText
            color: root.textColor; font.family: Theme.fontFamily; font.pixelSize: Metrics.fontSize
        }
        UI.Slider {
            id: seek
            objectName: "audioSeek"
            width: parent.width; height: 28
            padding: 0
            accessibleName: qsTr("Pozycja nagrania")
            tooltip: ""
            from: 0; to: Math.max(1, player.duration)
            value: player.position
            enabled: root.playbackEnabled && player.seekable && player.duration > 0
            stepSize: 1000
            onMoved: player.position = value
            KeyNavigation.left: play
            onActiveFocusChanged: if (activeFocus) root.ensureVisible(seek)
            Keys.onPressed: event => {
                if (event.modifiers !== Qt.NoModifier) return;
                if (event.key === Qt.Key_H || event.key === Qt.Key_L) player.position = Math.max(0, Math.min(player.duration, player.position + (event.key === Qt.Key_H ? -5000 : 5000)));
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!event.isAutoRepeat) root.toggle(); }
                else return;
                event.accepted = true;
            }
        }
        Text {
            objectName: "audioPosition"
            width: parent.width
            text: root.failed ? qsTr("Podgląd niedostępny") : player.duration > 0
                ? root.timeLabel(player.position) + " / " + root.timeLabel(player.duration) : root.sizeLabel
            color: root.mutedTextColor; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
            elide: Text.ElideRight; textFormat: Text.PlainText
        }
    }
}
