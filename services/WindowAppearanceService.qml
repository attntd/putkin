import QtQuick
import "../core"

// Theme changes, including a cancelled preview, share the same compositor path.
QtObject {
    id: root
    required property var backend
    property string applied: ""
    readonly property string signature: [Theme.accentBorder, Theme.accentSecondaryBorder,
        Theme.border, Metrics.borderWidth, Metrics.radius].join("|")

    function apply(): void {
        if (!backend.ready) { applied = ""; return; }
        if (applied === signature) return;
        backend.apply(Theme.accentBorder, Theme.accentSecondaryBorder, Theme.border,
            Metrics.borderWidth, Metrics.radius);
        applied = signature;
    }
    onSignatureChanged: Qt.callLater(apply)
    readonly property Connections changes: Connections {
        target: root.backend
        function onReadyChanged(): void { Qt.callLater(root.apply); }
        function onReloaded(): void { root.applied = ""; Qt.callLater(root.apply); }
    }
    Component.onCompleted: Qt.callLater(apply)
}
