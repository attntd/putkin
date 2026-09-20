import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "services"
import "preview"

ShellRoot {
    id: root
    NetworkBackend {
        id: backend
    }
    NetworkService {
        id: network
        backend: backend
        actionTimeout: 1200
        radioTimeout: 900
    }
    PanelPreviewWindow {
        id: preview
        network: network
    }
    IpcHandler {
        target: "probe"
        function snapshot(): string {
            const section = preview.scene.panelHost.window && preview.scene.panelHost.surfaceId === "network" ? preview.scene.panelHost.window.page.networkSection : null;
            return JSON.stringify({
                available: network.available,
                wifi: network.wifiEnabled,
                hardware: network.hardwareEnabled,
                internet: network.internetText,
                ethernet: network.ethernetConnected,
                status: network.statusText,
                radioBusy: network.radioBusy,
                error: network.lastError,
                backendError: backend.lastError,
                phase: network.phase,
                scanRequests: network.scanRequests,
                nativeScanners: Networking.devices.values.filter(device => device.type === DeviceType.Wifi && device.scannerEnabled).length,
                watcherPid: backend.watcherProcessId,
                devices: network.devices.map(d => ({
                            name: d.name,
                            type: d.type,
                            state: d.state,
                            scanning: d.type === 1 && d.scannerEnabled,
                            networks: d.networks.values.map(n => ({
                                        name: n.name,
                                        known: n.known,
                                        state: n.state,
                                        strength: n.signalStrength,
                                        security: n.security
                                    }))
                        })),
                loaded: preview.scene.panelHost.loaded,
                created: preview.scene.createdCount,
                destroyed: preview.scene.destroyedCount,
                passwordLength: section ? section.passwordField.text.length : 0,
                editorError: backend.editorError,
                generation: root.generation
            });
        }
        function expand(): void {
            preview.scene.panelHost.window.page.networkSection.expanded = true;
        }
        function activate(name: string): void {
            const device = network.wifiDevices[0];
            if (device)
                network.activate(device.networks.values.find(item => item.name === name));
        }
        function submitTestPassword(valid: bool): void {
            const section = preview.scene.panelHost.window.page.networkSection;
            section.passwordField.text = valid ? "putkin-" + "private-" + "psk-07" : "incorrect-" + "test-value";
            section.submit();
        }
        function cancel(): void {
            network.cancel();
        }
        function radio(value: bool): void {
            network.setWifiEnabled(value);
        }
        function editor(): void {
            network.openEditor();
        }
        function checkInternet(): void {
            network.checkInternet();
        }
        function reload(hard: bool): void {
            Quickshell.reload(hard);
        }
    }
    readonly property double generation: Date.now()
}
