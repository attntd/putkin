import QtQuick
import Quickshell
import Quickshell.Io
import "Appearance.js" as Appearance

// Serializes FileView operations. Signals are deferred: 0.3.1 clears its
// live operation only AFTER emitting loaded/saved/saveFailed.
QtObject {
    id: root
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    property string path: configHome + "/putkin/settings.json"
    property var snapshot: null
    property string phase: "idle"
    property var pending: null
    property bool refreshPending: false
    readonly property bool busy: pending !== null
    signal committed(string text)
    signal failed(string reason)

    function refresh(): void {
        refreshPending = true;
        Qt.callLater(pump);
    }
    function commit(text: string, expected: string): bool {
        if (busy) return false;
        pending = {text: text, expected: expected, written: false};
        refresh();
        return true;
    }
    function cancelBeforeWrite(): bool {
        if (!pending || pending.written || phase === "write") return false;
        pending = null;
        return true;
    }
    function pump(): void {
        if (phase !== "idle" || !refreshPending) return;
        refreshPending = false;
        phase = pending ? (pending.written ? "verify" : "check") : "read";
        file.reload();
    }
    function readDone(observed: var): void {
        const operation = phase;
        phase = "idle";
        snapshot = observed;
        if (pending && operation === "check") {
            if (observed.error || observed.token !== pending.expected) {
                pending = null;
                failed(observed.error ? "read" : "conflict");
            } else if (!observed.missing && observed.text === pending.text) {
                // FileView does not emit saved for identical content. This
                // fresh read has already confirmed that nothing needs writing.
                const text = pending.text;
                pending = null;
                committed(text);
            } else {
                phase = "write";
                file.setText(pending.text);
            }
        } else if (pending && operation === "verify") {
            const text = pending.text;
            pending = null;
            if (!observed.error && !observed.missing && observed.text === text)
                committed(text);
            else
                failed("verify");
        }
        Qt.callLater(pump);
    }
    function writeDone(error: bool): void {
        phase = "idle";
        if (error) {
            pending = null;
            failed("write");
        } else if (pending) {
            pending = {text: pending.text, expected: pending.expected, written: true};
        }
        // Also rearms watches after creation of a previously missing parent.
        refresh();
    }

    readonly property FileView file: FileView {
        watchChanges: true
        atomicWrites: true
        // Missing files are normal. All I/O errors are surfaced by Settings;
        // this does not suppress QML/import diagnostics.
        printErrors: false
        onLoaded: {
            const observed = Appearance.observation(text(), false, "");
            Qt.callLater(() => root.readDone(observed));
        }
        onLoadFailed: error => {
            const missing = error === FileViewError.FileNotFound;
            const observed = Appearance.observation("", missing, missing ? "" : FileViewError.toString(error));
            Qt.callLater(() => root.readDone(observed));
        }
        onSaved: Qt.callLater(() => root.writeDone(false))
        onSaveFailed: Qt.callLater(() => root.writeDone(true))
        onFileChanged: root.refresh()
    }
    // Observe creation of putkin/ without creating it merely by opening UI.
    // No read of the directory is requested, and no polling timer is needed.
    readonly property FileView parentWatch: FileView {
        path: root.configHome
        preload: false
        watchChanges: true
        onFileChanged: root.refresh()
    }
    Component.onCompleted: {
        // Put the initial asynchronous read through the same state machine;
        // opening an editor during startup must not overlap two reads.
        phase = "read";
        file.path = path;
    }
}
