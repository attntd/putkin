import QtQuick
import "../core"

QtObject {
    id: root
    property bool blocked: false
    property var current: null
    property var pending: []
    readonly property bool active: current !== null && !current.done
    readonly property int count: pending.length + (current ? 1 : 0)
    signal opened()
    function enqueue(request: var): bool {
        if (blocked || count >= 8 || request.done) { request.cancel(); request.release(); return false; }
        request.finished.connect(() => root.completed(request));
        pending = pending.concat([request]);
        advance();
        return true;
    }
    function advance(): void {
        if (current || blocked || pending.length === 0) return;
        const next = pending[0];
        pending = pending.slice(1);
        current = next;
        opened();
    }
    function completed(request: var): void {
        if (current === request) retirement.restart();
        else if (pending.indexOf(request) >= 0) {
            pending = pending.filter(item => item !== request);
            request.release();
        }
    }
    function cancelAll(): void {
        const queued = pending.slice();
        for (const request of queued) request.cancel();
        if (current && !current.done) current.cancel();
    }
    onBlockedChanged: { if (blocked) cancelAll(); else advance(); }
    readonly property Timer retirement: Timer {
        interval: Metrics.panelFade + 64
        onTriggered: {
            const old = root.current;
            root.current = null;
            if (old) old.release();
            root.advance();
        }
    }
    Component.onDestruction: cancelAll()
}
