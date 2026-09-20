pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

Scope {
    id: root
    required property var service
    readonly property var selectionSurface: selectionLoader.item
    readonly property var previewSurface: previewLoader.item
    readonly property bool selectionReady: selectionSurface !== null && selectionSurface.inputReady
    readonly property bool previewReady: previewSurface !== null && previewSurface.inputReady
    // Native surfaces exist only during their respective phase.
    LazyLoader {
        id: selectionLoader
        active: root.service.selecting || root.service.phase === "hiding"
        // Same factory metadata limitation as the other Quickshell windows.
        // qmllint disable uncreatable-type
        PanelWindow {
            // qmllint enable uncreatable-type
            id: selectionWindow
            readonly property bool inputReady: backingWindowVisible && selectionView.Window.active
            screen: root.service.screen
            visible: root.service.selecting
            anchors { left: true; top: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "putkin-screenshot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.service.selecting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            SelectionView { id: selectionView; anchors.fill: parent; service: root.service }
            onBackingWindowVisibleChanged: {
                if (!backingWindowVisible) Qt.callLater(root.service.unmapped);
            }
            onClosed: { if (selectionLoader.item === selectionWindow && root.service.selecting) root.service.close(); }
        }
    }
    LazyLoader {
        id: previewLoader
        active: root.service.previewing
        // qmllint disable uncreatable-type
        FloatingWindow {
            // qmllint enable uncreatable-type
            id: previewWindow
            readonly property bool inputReady: backingWindowVisible && previewView.Window.active
            screen: root.service.screen
            title: qsTr("Zrzut ekranu")
            readonly property real availableWidth: Math.max(Metrics.screenshotMinWidth,
                Math.min(Metrics.screenshotWidth, screen ? screen.width - 2 * Metrics.space24 : Metrics.screenshotWidth))
            readonly property real availableHeight: Math.max(Metrics.screenshotMinHeight,
                Math.min(Metrics.screenshotHeight, screen ? screen.height - Metrics.barHeight - 2 * Metrics.space24 : Metrics.screenshotHeight))
            readonly property int imagePadding: 2 * Metrics.space12
            readonly property int footerHeight: Metrics.controlHeight + 3 * Metrics.space12
            readonly property real factor: Math.min(1, (availableWidth - imagePadding) / Math.max(1, root.service.imageWidth),
                (availableHeight - footerHeight) / Math.max(1, root.service.imageHeight))
            implicitWidth: Math.max(Metrics.screenshotMinWidth, Math.round(root.service.imageWidth * factor + imagePadding))
            implicitHeight: Math.max(Metrics.screenshotMinHeight, Math.round(root.service.imageHeight * factor + footerHeight))
            // A fixed-size native toplevel is floated by Hyprland, without
            // permanent rules affecting unrelated Quickshell windows.
            minimumSize: Qt.size(implicitWidth, implicitHeight)
            maximumSize: minimumSize
            color: Theme.backgroundStrong
            ScreenshotPreview { id: previewView; anchors.fill: parent; service: root.service; onMoveRequested: previewWindow.startSystemMove() }
            onClosed: { if (previewLoader.item === previewWindow && root.service.previewing) root.service.close(); }
        }
    }
}
