import QtQuick

// Keep Qt's pixel scrolling, bounds and mouse wheel input. Wayland ends a
// finger scroll without platform momentum; continue it with Flickable's physics.
WheelHandler {
    id: root
    required property Flickable flickable
    parent: flickable
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    acceptedModifiers: Qt.NoModifier
    blocking: false
    enabled: flickable.enabled && flickable.visible && flickable.interactive
    property real velocity: 0
    property double lastSample: 0
    property int samples: 0

    function reset(): void { velocity = 0; lastSample = 0; samples = 0; }
    function coast(): void {
        if (active) return;
        if (enabled && samples > 1 && Date.now() - lastSample < 120
            && Math.abs(velocity) >= 120 && !flickable.flicking)
            flickable.flick(0, Math.max(-flickable.maximumFlickVelocity, Math.min(flickable.maximumFlickVelocity, velocity)));
        reset();
    }
    onActiveChanged: {
        if (active) { reset(); flickable.cancelFlick(); }
        else Qt.callLater(coast);
    }
    onWheel: event => {
        event.accepted = false;
        const delta = event.pixelDelta.y;
        if (!delta) return;
        const now = Date.now(), elapsed = now - lastSample;
        if (lastSample && elapsed > 0 && elapsed < 100) {
            const current = delta * 1000 / elapsed;
            velocity = velocity * current > 0 ? .25 * velocity + .75 * current : current;
            samples++;
        } else { velocity = 0; samples = 1; }
        lastSample = now;
    }
    onEnabledChanged: if (!enabled) { reset(); flickable.cancelFlick(); }
}
