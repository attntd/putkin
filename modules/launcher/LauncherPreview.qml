import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"
import "../../components" as UI

Controls.Control {
    id: root
    required property var service
    required property var launcherView
    property string previewText: service.previewText
    property string previewImage: service.previewImage
    readonly property bool contentReady: !previewImage.length || picture.status === Image.Ready || picture.status === Image.Error
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
        if (event.key === Qt.Key_H || event.key === Qt.Key_Left || DismissKeys.matches(event, root)) launcherView.focusResults();
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
            id: picture
            objectName: "launcherPreviewImage"
            anchors.fill: parent
            source: root.previewImage
            sourceSize: Qt.size(Metrics.launcherPreviewSize * 2, Metrics.launcherPreviewSize * 2)
            fillMode: Image.PreserveAspectFit
            autoTransform: true
            cache: false
            visible: source.toString().length > 0
        }
        Controls.ScrollView {
            id: scrollView
            anchors.fill: parent
            visible: root.previewImage.length === 0
            contentWidth: availableWidth
            rightPadding: Metrics.space12 + Metrics.space4
            focusPolicy: Qt.NoFocus
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.vertical: UI.ScrollBar {
                objectName: "launcherPreviewScrollbar"
                parent: scrollView
                x: scrollView.width - width
                y: scrollView.topPadding
                height: scrollView.availableHeight
                onPressedChanged: { if (pressed) root.focusReason = Qt.MouseFocusReason; }
            }
            Flickable {
                id: textView
                objectName: "launcherPreviewScroll"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: content.implicitHeight
                // ScrollView filters pointer events before the outer Control.
                // Keep its text click on the same keyboard navigation target.
                TapHandler {
                    gesturePolicy: TapHandler.DragThreshold
                    onPressedChanged: {
                        if (!pressed) return;
                        root.focusReason = Qt.MouseFocusReason;
                        root.forceActiveFocus(Qt.MouseFocusReason);
                    }
                }
                UI.PanelText {
                    id: content
                    objectName: "launcherPreviewText"
                    width: textView.width
                    text: root.previewText
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    onTextChanged: textView.contentY = 0
                }
            }
        }
    }
}
