import QtQml
import Quickshell.Services.SystemTray

QtObject {
    // Keep the native object model and identities; views only choose visibility.
    readonly property var items: SystemTray.items
}
