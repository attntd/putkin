import QtQuick
import Quickshell
import Quickshell.Services.Pam

QtObject {
    id: root
    property string configDirectory: Quickshell.shellPath("config/pam.d")
    property bool fingerprintAvailable: false
    property int epoch: 0
    property bool enabled: false
    property string secret: ""
    property bool delivered: false
    readonly property bool passwordBusy: password.active
    signal succeeded(int epoch, string method)
    signal failed(int epoch, string method)

    function begin(value: int): void {
        stop();
        epoch = value;
        enabled = true;
        if (fingerprintAvailable) finger.start();
    }
    function stop(): void {
        enabled = false;
        secret = "";
        retry.stop();
        password.abort();
        finger.abort();
    }
    function submit(value: int, text: string): bool {
        if (!enabled || value !== epoch || password.active) return false;
        secret = text;
        delivered = false;
        if (password.start()) return true;
        secret = "";
        failed(epoch, "password");
        return false;
    }
    readonly property PamContext password: PamContext {
        configDirectory: root.configDirectory
        config: "putkin-password"
        onPamMessage: {
            if (!responseRequired) return;
            // The password stack accepts one secret. Never send a password to
            // a visible/user-name prompt or repeat it for an unexpected prompt.
            if (!root.enabled || responseVisible || root.delivered) {
                abort(); root.secret = ""; root.failed(root.epoch, "password");
                return;
            }
            root.delivered = true;
            respond(root.secret);
            root.secret = "";
        }
        onCompleted: result => {
            root.secret = "";
            if (!root.enabled) return;
            if (result === PamResult.Success) root.succeeded(root.epoch, "password");
            else root.failed(root.epoch, "password");
        }
    }
    readonly property PamContext finger: PamContext {
        configDirectory: root.configDirectory
        config: "putkin-fingerprint"
        onPamMessage: {
            if (responseRequired) { abort(); root.failed(root.epoch, "fingerprint"); }
            else if (messageIsError && root.enabled) root.failed(root.epoch, "fingerprint");
        }
        onCompleted: result => {
            if (!root.enabled) return;
            if (result === PamResult.Success) root.succeeded(root.epoch, "fingerprint");
            else {
                root.failed(root.epoch, "fingerprint");
                // Retry an ordinary failed scan. Errors/MaxTries wait for the
                // next lock, leaving password authentication available.
                if (result === PamResult.Failed) root.retry.restart();
            }
        }
    }
    readonly property Timer retry: Timer {
        interval: 2000
        onTriggered: { if (root.enabled && root.fingerprintAvailable) root.finger.start(); }
    }
    onFingerprintAvailableChanged: {
        if (!fingerprintAvailable) { retry.stop(); finger.abort(); }
        else if (enabled && !finger.active) finger.start();
    }
}
