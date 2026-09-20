import QtQuick
import Quickshell
import "../core"
import "../services"
import "../modules/bar"

FloatingWindow {
    id: root
    readonly property string screenshotPath: Quickshell.env("PUTKIN_SCREENSHOT") || ""
    readonly property string scenario: Quickshell.env("PUTKIN_SCENARIO") || "basic"
    title: "Putkin — podgląd paska"
    implicitWidth: Number(Quickshell.env("PUTKIN_PREVIEW_WIDTH")) || 1920
    implicitHeight: Number(Quickshell.env("PUTKIN_PREVIEW_HEIGHT")) || 1080
    color: Theme.backgroundStrong
    visible: true

    MockHyprland { id: mock }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: Quickshell.env("PUTKIN_LIVE_CLOCK") === "1"
    }
    WorkspaceService { id: service; backend: mock }
    BarFocus { id: controller; service: service; screenNames: ["TEST-1", "TEST-2"] }
    BarIpc { controller: controller }

    Rectangle {
        id: scene
        anchors.fill: parent
        color: Theme.backgroundStrong
        BarView {
            id: bar
            width: parent.width
            height: Metrics.barHeight
            service: service
            screenName: "TEST-1"
            date: clock.enabled ? clock.date : new Date(2026, 8, 16, 22, 57)
            navigating: controller.screenName === screenName
            onDismissed: controller.close()
        }
    }
    Connections {
        target: controller
        function onEntered(name: string): void {
            if (name === "TEST-1") {
                if (scene.Window.window)
                    scene.Window.window.requestActivate();
                bar.workspaces.enter();
            }
        }
    }
    Timer {
        interval: 350
        running: root.screenshotPath.length > 0
        onTriggered: {
            if (!scene.grabToImage(result => {
                if (result.saveToFile(root.screenshotPath))
                    console.info("PUTKIN_SCREENSHOT_SAVED");
                else
                    console.error("PUTKIN_SCREENSHOT_FAILED");
            }))
                console.error("PUTKIN_SCREENSHOT_FAILED");
        }
    }
    Component.onCompleted: {
        if (scenario === "overflow" || scenario === "focus")
            mock.many();
        if (scenario === "unavailable")
            mock.connected = false;
        if (scenario === "focus")
            Qt.callLater(controller.focusBar);
        console.info("PUTKIN_PREVIEW_READY");
    }
}
