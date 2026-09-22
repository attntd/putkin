import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"

// Same runtime factory metadata limitation as BarWindow (Quickshell 0.3.1).
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root
    required property var host
    property bool refreshingGrab: false
    // Map only after asynchronous construction has produced the full page.
    // An empty first frame otherwise maps a 24 px panel and races the grab.
    visible: host.loaded && surface.page !== null
    function dismissFromCompositor(): void {
        // A late event from a retiring window cannot close its replacement.
        if (host.window === root && host.interactive)
            host.coordinator.close(false);
    }
    function recoverGrab(): void {
        if (!host.interactive || !backingWindowVisible || !grab.active || surface.Window.active) return;
        refreshingGrab = true;
        grabRefresh.restart();
    }
    // A passive layer can unmap before this new window receives its first
    // activation, so activeChanged alone cannot detect the missed handoff.
    onBackingWindowVisibleChanged: { if (backingWindowVisible) initialFocusCheck.restart(); }
    screen: host.screen
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    // Transparent padding also avoids the unresolved Margins value type in
    // the shipped 0.3.1 qmltypes. Only the actual panel accepts pointer input.
    implicitWidth: host.screen ? host.screen.width - host.surfaceX : 1
    // A content-sized Wayland buffer can be stretched for one frame while a
    // smaller configure is acknowledged. Keep the canvas stable as sections
    // collapse; the surface and input mask still follow the visible content.
    implicitHeight: host.screen ? host.screen.height : 1
    color: "transparent"
    WlrLayershell.namespace: "putkin-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    // The grab focuses this window and handles outside clicks. Exclusive
    // layer focus would route those clicks back here on Hyprland 0.56.2.
    WlrLayershell.keyboardFocus: host.interactive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        x: surface.x
        y: surface.y
        width: root.host.interactive ? root.host.surfaceWidth : 0
        height: root.host.interactive ? surface.primaryHeight : 0
        Region {
            x: surface.x + root.host.surfaceWidth + Metrics.panelGap
            y: surface.y
            width: root.host.interactive ? surface.previewWidth : 0
            height: width
        }
    }
    PanelSurface {
        id: surface
        host: root.host
        y: root.host.surfaceY(height)
        width: root.host.surfaceExtentWidth
        height: Math.min(implicitHeight, root.host.availableHeight)
    }
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: root.host.interactive && root.backingWindowVisible && !root.refreshingGrab
        onCleared: root.dismissFromCompositor()
    }
    Connections {
        target: surface.Window.window
        function onActiveChanged(): void {
            // Hyprland 0.56 can refocus a client while an unrelated passive
            // layer unmaps. Renew only a still-authorized, interactive grab;
            // outside-click dismissal clears host.interactive first.
            // The attached Window.active can lag QWindow.activeChanged.
            // Read it only after both notifications have settled.
            if (!root.host.interactive) return;
            Qt.callLater(root.recoverGrab);
        }
    }
    Timer {
        id: initialFocusCheck
        interval: 50
        onTriggered: root.recoverGrab()
    }
    Timer {
        id: grabRefresh
        // Allow Hyprland to process the removed grab before recreating it.
        // Two callLater callbacks can send both requests in the same batch.
        interval: 16
        onTriggered: root.refreshingGrab = false
    }
    onClosed: dismissFromCompositor()
}
