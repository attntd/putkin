//@ pragma Env QS_PIPEWIRE_IMMEDIATE_RECONNECT = 1
// Isolated test entrypoint: real PipeWire adapter, mock monitors, Item OSD.
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "preview"

ShellRoot {
    PipewireBackend { id: backend }
    AudioService { id: audioService; backend: backend }
    AudioIpc { audio: audioService }
    PanelPreviewWindow { id: window; audio: audioService }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const scene = window.scene;
            return JSON.stringify({
                ready: backend.ready, available: audioService.available,
                volume: audioService.volume, muted: audioService.muted,
                output: audioService.defaultOutput ? audioService.defaultOutput.name : "",
                outputs: audioService.outputs.map(node => ({ id: node.id, name: node.name })),
                busy: audioService.busy, error: audioService.lastError,
                refreshing: backend.refreshing, tracked: backend.tracker.objects.length,
                inputAvailable: audioService.microphone.available,
                inputVolume: audioService.microphone.volume, inputMuted: audioService.microphone.muted,
                input: audioService.microphone.defaultDevice ? audioService.microphone.defaultDevice.name : "",
                inputs: audioService.microphone.devices.map(node => ({id: node.id, name: node.name})),
                inputBusy: audioService.microphone.busy, inputError: audioService.microphone.lastError,
                inputRefreshing: backend.input.refreshing, inputTracked: backend.input.tracker.objects.length,
                osd: scene.osd.visible, osdLoaded: scene.osdHost.loaded,
                created: scene.osdCreated, destroyed: scene.osdDestroyed,
                screen: scene.osd.screen ? scene.osd.screen.name : "",
                panel: scene.coordinator.activeId,
                focus: scene.Window.window && scene.Window.window.activeFocusItem
                    ? scene.Window.window.activeFocusItem.objectName : ""
            });
        }
        function selectOutput(name: string): bool {
            return audioService.selectOutput(audioService.outputs.find(node => node.name === name), "");
        }
        function selectInput(name: string): bool {
            return audioService.microphone.selectDevice(audioService.microphone.devices.find(node => node.name === name), "");
        }
        function setInputVolume(value: real): bool { return audioService.microphone.setVolume(value, ""); }
        function toggleInputMute(): bool { return audioService.microphone.toggleMute(""); }
        function setMonitor(name: string): void { window.scene.backend.focusedMonitorName = name; }
        function removeSecond(): void { window.scene.coordinator.screens = [window.scene.firstScreen]; }
        function hideOsd(): void { window.scene.osd.hide(); }
        function timeout(milliseconds: int): void { window.scene.osd.timeout = milliseconds; }
        function reload(hard: bool): void { Quickshell.reload(hard); }
    }
}
