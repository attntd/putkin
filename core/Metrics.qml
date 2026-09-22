pragma Singleton

import QtQuick

QtObject {
    readonly property int radius: 0
    readonly property int borderWidth: 2
    readonly property int focusWidth: 2
    readonly property int focusOffset: 4
    readonly property int space4: 4
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space24: 24
    readonly property int controlHeight: 36
    readonly property int barHeight: 32
    readonly property int workspaceWidth: 36
    readonly property int workspaceMaxWidth: 480
    readonly property int barStatusReserve: 32
    readonly property int trayButtonWidth: 32
    readonly property int trayVisibleLimit: 4
    readonly property int fontSize: 13
    readonly property int batteryPercentageFontSize: 28
    readonly property int smallFontSize: 12
    // Every icon in a section shares its SVG canvas and internal padding.
    readonly property var iconSections: ({
        bar: {size: 20, padding: 6, verticalPadding: 5},
        launcher: {size: 24, padding: 4},
        slider: {size: 24, padding: 6},
        tile: {size: 24, padding: 4},
        list: {size: 20, padding: 4},
        notification: {size: 24, padding: 6},
        osd: {size: 24, padding: 4}
    })
    readonly property int tooltipDelay: 600
    readonly property int launcherWidth: 640
    readonly property int launcherVisibleResults: 5
    readonly property int launcherPreviewSize: 320
    readonly property int launcherPreviewMinimum: 160
    readonly property int launcherClipboardRowHeight: 36
    readonly property int screenshotWidth: 960
    readonly property int screenshotHeight: 640
    readonly property int screenshotMinWidth: 240
    readonly property int screenshotMinHeight: 180
    readonly property int launcherRowHeight: 52
    readonly property int panelWidth: 360
    readonly property int settingsWidth: 720
    readonly property int settingsHeight: 680
    readonly property int panelGap: 8
    readonly property int panelFade: 200
    readonly property int osdWidth: 320
    readonly property int osdHeight: 52
    readonly property int osdTimeout: 1500
    readonly property int toastWidth: 360
    readonly property int toastMinHeight: 132
    readonly property int toastMaxHeight: 280
    readonly property int toastImageHeight: 100
}
