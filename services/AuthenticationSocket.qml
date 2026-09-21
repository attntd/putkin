import QtQuick
import Quickshell.Io
import "AuthenticationMessages.js" as Messages

AuthenticationRequest {
    id: root
    required property string socketPath
    required property var service
    property bool received: false
    property bool queued: false
    property bool disposed: false
    function receive(line: string): void {
        if (done) return;
        let data;
        try {
            if (line.length > 32768) throw new Error("size");
            data = JSON.parse(line);
            if (received) { if (data.closed === true) finish(); return; }
            if (["ssh", "sudo", "gpg"].indexOf(data.source) < 0
                    || ["input", "confirm", "none", "message"].indexOf(data.mode) < 0
                    || typeof data.message !== "string" || data.message.length > 8192
                    || typeof data.prompt !== "string" || data.prompt.length > 1024) throw new Error("request");
        } catch (_) { cancel(); return; }
        received = true;
        handshake.stop();
        const copy = Messages.describe(data.source, data.mode, data.message, data.prompt);
        title = copy.title; context = copy.context; prompt = copy.prompt;
        mode = copy.mode; acceptText = copy.accept;
        if (data.source === "gpg" && typeof data.accept === "string" && data.accept) acceptText = data.accept.slice(0, 128);
        if (data.source === "gpg" && typeof data.reject === "string") rejectText = data.reject.slice(0, 128);
        errorText = typeof data.error === "string" ? data.error.slice(0, 4096) : "";
        invalid = errorText.length > 0;
        responseRequired = mode !== "touch";
        queued = true;
        service.enqueue(root);
    }
    function reply(response: string, accepted: bool, rejected: bool): void {
        if (done) return;
        channel.write(JSON.stringify({accepted: accepted, response: response, rejected: rejected}) + "\n");
        channel.flush();
        finish();
    }
    function submit(response: string): void { if (responseRequired && !done) reply(response, true, false); }
    function cancel(): void { reply("", false, false); }
    function reject(): void { reply("", false, true); }
    onFinished: { channel.connected = false; if (!queued) Qt.callLater(release); }
    function release(): void {
        if (disposed) return;
        disposed = true;
        channel.connected = false;
        released(); destroy();
    }
    readonly property Socket channel: Socket {
        path: root.socketPath
        connected: true
        parser: SplitParser { onRead: line => root.receive(line) }
        onConnectionStateChanged: { if (!connected) root.finish(); }
        // LocalSocketError is absent from Quickshell 0.3.1's qmltypes.
        Component.onCompleted: error.connect(() => root.finish())
    }
    readonly property Timer handshake: Timer { interval: 6000; running: true; onTriggered: root.cancel() }
}
