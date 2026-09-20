import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../components"

FocusScope {
    id: root
    required property var service
    readonly property bool accentScope: true
    signal moveRequested()
    focus: true
    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundStrong
        // The native floating window already has the shared compositor frame.
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.space12
        spacing: Metrics.space12
        Image {
            objectName: "screenshotImage"
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: root.service.imageSource
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: true
            MouseArea { anchors.fill: parent; onPressed: root.moveRequested() }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Metrics.space8
            Button {
                id: save
                objectName: "screenshotSave"
                text: qsTr("Zapisz")
                tooltip: ""
                enabled: root.service.phase === "preview"
                onClicked: root.service.save()
                KeyNavigation.right: close
                KeyNavigation.down: close
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_L || event.key === Qt.Key_J) { close.forceActiveFocus(Qt.TabFocusReason); event.accepted = true; }
                }
            }
            Button {
                id: close
                objectName: "screenshotClose"
                text: qsTr("Zamknij")
                tooltip: ""
                onClicked: root.service.close()
                KeyNavigation.left: save
                KeyNavigation.up: save
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_H || event.key === Qt.Key_K) { save.forceActiveFocus(Qt.TabFocusReason); event.accepted = true; }
                }
            }
        }
    }
    Keys.onPressed: event => {
        if (event.isAutoRepeat) { event.accepted = true; return; }
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) root.service.close();
        else if (event.key === Qt.Key_F || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.service.save();
        else if ([Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L].indexOf(event.key) >= 0) save.forceActiveFocus(Qt.TabFocusReason);
        else return;
        event.accepted = true;
    }
}
