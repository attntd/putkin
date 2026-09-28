import QtQuick
import "../../core"
import "../../components" as UI

Rectangle {
    id: root
    property var conversation: null
    readonly property string title: conversation ? conversation.title || "" : ""
    readonly property string initials: title.trim().split(/\s+/).slice(0, 2).map(word => Array.from(word)[0] || "").join("").toLocaleUpperCase()
    readonly property string kind: conversation ? conversation.kind || "direct" : "direct"
    readonly property bool hasImage: picture.status === Image.Ready
    implicitWidth: 40
    implicitHeight: 40
    color: Theme.surface
    radius: Metrics.radius
    clip: true
    Image {
        id: picture
        objectName: "avatarImage"
        anchors.fill: parent
        source: root.conversation && String(root.conversation.avatar || "").startsWith("file:") ? root.conversation.avatar : ""
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Text {
        anchors.centerIn: parent
        visible: !root.hasImage && root.kind === "direct" && root.initials.length > 0 && !/^([+\d]|aci:|pni:)/.test(root.title)
        text: root.initials
        textFormat: Text.PlainText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.height * .38)
    }
    UI.Glyph {
        anchors.centerIn: parent
        visible: !root.hasImage && (root.kind !== "direct" || !root.initials || /^([+\d]|aci:|pni:)/.test(root.title))
        symbol: root.kind === "group" ? "groups" : root.kind === "note" ? "description" : "person"
    }
}
