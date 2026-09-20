import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Controls.Control {
    id: root
    required property var service
    required property var launcherView
    objectName: "launcherPreview"
    padding: Metrics.space12
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Podgląd schowka"
    Keys.forwardTo: [input]
    UI.ControlInput { id: input; control: root }
    KeyNavigation.tab: launcherView.firstControl
    KeyNavigation.backtab: launcherView.resultsControl
    Component.onDestruction: {
        if (activeFocus && launcherView && launcherView.enabled) launcherView.focusResults();
    }

    function scroll(offset: real): void {
        textView.contentY = Math.max(0, Math.min(textView.contentHeight - textView.height, textView.contentY + offset));
    }
    Keys.onPressed: event => {
        if (event.modifiers !== Qt.NoModifier && event.modifiers !== Qt.KeypadModifier) return;
        if (event.key === Qt.Key_H || event.key === Qt.Key_Left || event.key === Qt.Key_Escape) launcherView.focusResults();
        else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) scroll(Metrics.launcherClipboardRowHeight);
        else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) scroll(-Metrics.launcherClipboardRowHeight);
        else if (event.key === Qt.Key_PageDown) scroll(textView.height);
        else if (event.key === Qt.Key_PageUp) scroll(-textView.height);
        else if (event.key === Qt.Key_Slash || event.key === Qt.Key_I) launcherView.focusInitial();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat) launcherView.activate();
        } else return;
        event.accepted = true;
    }
    background: UI.AccentRectangle {
        color: Theme.backgroundStrong
        border.width: Metrics.borderWidth
        border.color: Theme.accentBorder
        accentOutline: true
        UI.FocusIndicator { control: root; anchors.margins: Metrics.focusOffset }
    }
    contentItem: Item {
        Image {
            objectName: "launcherPreviewImage"
            anchors.fill: parent
            source: root.service.previewImage
            sourceSize: Qt.size(Metrics.launcherPreviewSize * 2, Metrics.launcherPreviewSize * 2)
            fillMode: Image.PreserveAspectFit
            autoTransform: true
            cache: false
            visible: source.toString().length > 0
        }
        Controls.ScrollView {
            anchors.fill: parent
            visible: root.service.previewImage.length === 0
            contentWidth: availableWidth
            focusPolicy: Qt.NoFocus
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            Flickable {
                id: textView
                objectName: "launcherPreviewScroll"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: content.implicitHeight
                UI.PanelText {
                    id: content
                    objectName: "launcherPreviewText"
                    width: textView.width
                    text: root.service.previewText
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    onTextChanged: textView.contentY = 0
                }
            }
        }
    }
}
