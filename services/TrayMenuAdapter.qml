import Quickshell

QsMenuOpener {
    // The opener keeps DBusMenu referenced, requests AboutToShow and releases
    // it on destruction. Submenu openers live alongside their parent opener.
    property var handle: null
    menu: handle
    readonly property var entries: children
}
