import QtQuick
import "../core/Appearance.js" as Appearance

QtObject {
    id: root
    property var snapshot: Appearance.observation("", true, "")
    property var pending: null
    property int writes: 0
    property bool autoComplete: true
    signal committed(string text)
    signal failed(string reason)
    function refresh(): void { snapshot = Appearance.copy(snapshot); }
    function commit(text: string, expected: string): bool {
        if (pending) return false;
        pending = {text: text, expected: expected};
        if (autoComplete) Qt.callLater(complete);
        return true;
    }
    function complete(): void {
        if (!pending) return;
        const request = pending;
        pending = null;
        if (request.expected !== snapshot.token) { failed("conflict"); return; }
        writes++;
        snapshot = Appearance.observation(request.text, false, "");
        committed(request.text);
    }
    function cancelBeforeWrite(): bool {
        if (!pending) return false;
        pending = null;
        return true;
    }
    function external(text: string): void { snapshot = Appearance.observation(text, false, ""); }
}
