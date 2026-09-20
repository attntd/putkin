// A separate application process for compositor focus/input assertions.
import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

ShellRoot {
    FloatingWindow {
        id: window
        title: "Putkin private input test"
        implicitWidth: 420; implicitHeight: 160
        color: "#1e1e2e"
        TextField {
            id: field
            anchors.centerIn: parent
            width: parent.width - 24
            focus: true
            placeholderText: "Testowe pole wejścia — bez prywatnych danych"
        }
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string { return JSON.stringify({text: field.text, focus: field.activeFocus, windowActive: window.contentItem.Window.window.active}); }
        function clear(): void { field.text = ""; }
        function setWindowVisible(enabled: bool): void { window.visible = enabled; }
    }
}
