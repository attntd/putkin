import QtQml
import Quickshell.Io

QtObject {
    id: root
    required property var audio
    readonly property IpcHandler handler: IpcHandler {
        target: "audio"
        function setVolume(percent: real): string { return root.audio.setVolume(percent, "") ? "accepted" : root.audio.lastError; }
        function changeVolume(points: real): string { return root.audio.changeVolume(points, "") ? "accepted" : root.audio.lastError; }
        function toggleMute(): string { return root.audio.toggleMute("") ? "accepted" : root.audio.lastError; }
        function setMuted(muted: bool): string { return root.audio.setMuted(muted, "") ? "accepted" : root.audio.lastError; }
        function status(): string {
            return JSON.stringify({ available: root.audio.available, output: root.audio.outputName,
                volume: root.audio.available ? root.audio.volume : null, muted: root.audio.muted, busy: root.audio.busy, error: root.audio.lastError });
        }
    }
}
