import QtQuick
import "../../core"

Rectangle {
    id: root
    required property var service
    property real pixelScale: 1
    readonly property int imageStatus: picture.status
    readonly property bool fallbackVisible: picture.status !== Image.Ready
    readonly property string diagnostic: picture.status === Image.Error ? qsTr("Nie można wczytać tapety. Wyświetlono tło Mocha.") : service.diagnostic
    color: Theme.background
    clip: true
    Image {
        id: picture
        anchors.fill: parent
        source: root.service.source
        asynchronous: true
        cache: false
        autoTransform: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(root.width * root.pixelScale), Math.ceil(root.height * root.pixelScale))
        visible: status === Image.Ready
    }
}
