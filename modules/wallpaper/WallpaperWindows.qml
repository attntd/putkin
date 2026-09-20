pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Variants {
    id: root
    required property var service
    model: service.enabled ? Quickshell.screens : []
    WallpaperWindow {
        required property ShellScreen modelData
        screen: modelData
        service: root.service
    }
}
