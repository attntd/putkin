pragma ComponentBehavior: Bound
import QtQuick
import "../../core"
import "../../components" as UI

Column {
    id: root
    required property var attachment
    property color textColor: Theme.text
    property color mutedTextColor: Theme.textMuted
    readonly property bool hasThumbnail: !!(attachment.thumbnail || attachment.preview)
    readonly property bool video: /^video\//.test(attachment.content_type)
    readonly property bool audio: /^audio\//.test(attachment.content_type) || attachment.content_type === "application/ogg"
    signal previewRequested(var attachment, int reason)
    spacing: Metrics.space4
    UI.NavigationButton {
        id: preview
        objectName: "previewAttachment"
        width: root.width
        height: root.hasThumbnail ? 160 : Metrics.controlHeight
        padding: 0
        horizontalPadding: 0
        verticalPadding: 0
        text: qsTr("Podgląd załącznika")
        Accessible.name: text + ": " + root.attachment.filename
        enabled: root.attachment.state === "ready"
        foreground: root.textColor
        onEnsureVisible: item => root.ensureVisible(item)
        onClicked: root.previewRequested(root.attachment, preview.focusReason)
        background: Item {
            UI.FocusIndicator { control: preview; border.color: root.textColor; accentOutline: false }
        }
        contentItem: Item {
            Image {
                id: thumbnail
                anchors.fill: parent
                visible: root.hasThumbnail
                source: root.attachment.thumbnail || root.attachment.preview || ""
                asynchronous: true
                cache: false
                sourceSize: Qt.size(384, 384)
                fillMode: Image.PreserveAspectFit
            }
            Row {
                anchors.centerIn: parent
                spacing: Metrics.space8
                visible: !root.hasThumbnail || thumbnail.status === Image.Error
                UI.Glyph {
                    symbol: root.video ? "videocam" : root.audio ? "music_note" : "description"
                    color: root.textColor
                }
                Text {
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: root.video ? qsTr("Film") : root.audio ? qsTr("Dźwięk") : qsTr("Załącznik")
                    color: root.textColor
                    font: preview.font
                }
            }
        }
    }
    Text {
        width: root.width
        visible: root.attachment.state !== "ready" || root.attachment.errorCode !== ""
        text: root.attachment.state === "pending" ? qsTr("Przygotowywanie…")
            : root.attachment.state !== "ready" ? qsTr("Załącznik niedostępny") : qsTr("Podgląd formatu niedostępny")
        color: root.mutedTextColor
        font.family: Theme.fontFamily
        font.pixelSize: Metrics.smallFontSize
        wrapMode: Text.Wrap
    }
    signal ensureVisible(Item item)
}
