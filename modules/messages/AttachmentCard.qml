pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var attachment
    property color textColor: Theme.text
    property color mutedTextColor: Theme.textMuted
    property real mediaHeight: 0
    property bool playbackEnabled: false
    property var audioOwner: null
    readonly property bool visual: /^(image|video)\//.test(attachment.content_type)
    readonly property bool video: /^video\//.test(attachment.content_type)
    readonly property bool audio: /^audio\//.test(attachment.content_type) || attachment.content_type === "application/ogg"
    // Originals have already passed the backend's MIME/dimension checks.
    // Keep video posters separate and never decode a rejected original here.
    readonly property string imageSource: !video && visual && !attachment.errorCode && attachment.url
        ? attachment.url : attachment.thumbnail || attachment.preview || ""
    readonly property bool hasThumbnail: visual && !!imageSource
    readonly property bool ready: attachment.state === "ready"
    readonly property string sizeLabel: {
        const bytes = Number(attachment.size_bytes || 0);
        if (bytes < 1000) return bytes + " B";
        if (bytes < 1000000) return (bytes / 1000).toFixed(bytes < 10000 ? 1 : 0) + " kB";
        return (bytes / 1000000).toFixed(1) + " MB";
    }
    signal previewRequested(var attachment, int reason)
    signal ensureVisible(Item item)
    spacing: Metrics.space4
    UI.NavigationButton {
        id: preview
        objectName: "previewAttachment"
        width: root.width
        height: root.visual ? (root.mediaHeight || Math.min(root.width * 1.5, Math.max(root.width * .5,
            thumbnail.implicitWidth > 0 ? root.width * thumbnail.implicitHeight / thumbnail.implicitWidth : root.width))) : 56
        visible: !root.audio
        padding: 0
        tooltip: ""
        text: root.video ? qsTr("Odtwórz film") : root.visual ? qsTr("Podgląd zdjęcia") : root.attachment.filename
        Accessible.name: text + ": " + root.attachment.filename
        enabled: root.ready
        foreground: root.textColor
        onEnsureVisible: item => root.ensureVisible(item)
        onClicked: root.previewRequested(root.attachment, preview.focusReason)
        background: Rectangle { color: root.visual ? Theme.backgroundStrong : "transparent" }
        contentItem: Item {
            clip: true
            Image {
                id: thumbnail
                objectName: "attachmentThumbnail"
                anchors.fill: parent
                visible: root.hasThumbnail
                source: root.imageSource
                asynchronous: true
                cache: false
                autoTransform: true
                mipmap: true
                retainWhileLoading: true
                sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)),
                    root.mediaHeight > 0 ? Math.max(1, Math.ceil(height * Screen.devicePixelRatio)) : -1)
                fillMode: Image.PreserveAspectCrop
            }
            UI.Glyph {
                anchors.centerIn: parent
                visible: root.visual && !root.video && (!root.hasThumbnail || thumbnail.status === Image.Error)
                symbol: root.ready ? "image" : "download"
                color: Theme.text
            }
            Rectangle {
                objectName: "videoPlayBadge"
                visible: root.video
                anchors.centerIn: parent
                width: 44; height: 44; radius: 22
                color: Qt.rgba(0, 0, 0, .55)
                UI.Glyph { anchors.centerIn: parent; symbol: "play_arrow"; color: "white" }
            }
            Row {
                visible: !root.visual
                anchors.fill: parent
                spacing: Metrics.space8
                Item {
                    width: 36; height: parent.height
                    UI.Glyph { anchors.centerIn: parent; symbol: "description"; color: root.textColor; width: 32; height: 32 }
                }
                Column {
                    width: Math.max(0, parent.width - 44)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.space4
                    Text {
                        objectName: "attachmentCardFilename"
                        width: parent.width
                        text: root.attachment.filename || ""
                        elide: Text.ElideMiddle; textFormat: Text.PlainText
                        color: root.textColor; font: preview.font
                    }
                    Text {
                        objectName: "attachmentCardSize"
                        width: parent.width
                        text: root.sizeLabel
                        elide: Text.ElideRight; textFormat: Text.PlainText
                        color: root.mutedTextColor; font.family: Theme.fontFamily; font.pixelSize: Metrics.smallFontSize
                    }
                }
            }
            UI.FocusIndicator { control: preview; border.color: root.textColor; accentOutline: false }
        }
    }
    Loader {
        width: root.width
        active: root.audio
        visible: active
        sourceComponent: AudioAttachment {
            attachment: root.attachment
            sizeLabel: root.sizeLabel
            textColor: root.textColor
            mutedTextColor: root.mutedTextColor
            playbackEnabled: root.playbackEnabled && root.ready
            audioOwner: root.audioOwner
            onEnsureVisible: item => root.ensureVisible(item)
        }
    }
    Text {
        objectName: "attachmentAvailability"
        width: root.width
        visible: !root.ready || !!root.attachment.errorCode
        text: root.attachment.state === "pending" ? qsTr("Przygotowywanie…")
            : !root.ready ? qsTr("Załącznik niedostępny") : qsTr("Podgląd formatu niedostępny")
        color: root.mutedTextColor
        font.family: Theme.fontFamily
        font.pixelSize: Metrics.smallFontSize
        wrapMode: Text.Wrap
    }
}
