import QtQuick
import Quickshell
import "../core"

FloatingWindow {
    id: root

    readonly property string screenshotPath: Quickshell.env("PUTKIN_SCREENSHOT") || ""

    title: "Putkin — podgląd fundamentu"
    implicitWidth: 720
    implicitHeight: 440
    minimumSize: Qt.size(520, 440)
    color: Theme.background
    visible: true

    onBackingWindowVisibleChanged: {
        if (backingWindowVisible && view.Window.window) {
            view.Window.window.requestActivate();
            view.focusFirst();
        }
    }

    MockState { id: mock }

    FoundationView {
        id: view
        anchors.fill: parent
        model: mock
        Component.onCompleted: focusFirst()
    }

    // One shot for reproducible evidence. No timer runs during idle measurement.
    Timer {
        interval: 350
        running: root.screenshotPath.length > 0
        onTriggered: {
            view.focusFirst();
            if (!view.grabToImage(result => {
                if (result.saveToFile(root.screenshotPath))
                    console.info("PUTKIN_SCREENSHOT_SAVED");
                else
                    console.error("PUTKIN_SCREENSHOT_FAILED");
            }))
                console.error("PUTKIN_SCREENSHOT_FAILED");
        }
    }
    Component.onCompleted: console.info("PUTKIN_PREVIEW_READY")
}
