pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/settings"

Item {
    id: scene
    width: 720
    height: 900
    readonly property bool accentScope: true
    MockSignalBackend { id: backend }
    SignalService { id: service; backend: backend }
    MockSettingsFile { id: storage }
    Settings { id: settings; storage: storage }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    Loader {
        id: loader
        width: 600
        sourceComponent: SettingsView { settings: scene.appearanceSettings; signalService: service }
    }
    readonly property var appearanceSettings: settings
    SignalSpy { id: changes; target: service; signalName: "changed" }
    TestCase {
        name: "SignalSettings"
        when: windowShown
        function control(name) { return findChild(loader.item, name); }
        function init() {
            failOnWarning(/.*/);
            loader.active = false;
            backend.reset();
            settings.cancelEdit(); settings.beginEdit();
            loader.active = true;
            tryCompare(loader, "status", Loader.Ready);
            loader.item.section = "signal";
            tryVerify(() => control("signalPrimary") !== null);
            changes.clear();
        }
        function cleanup() { loader.active = false; service.clearQr(); settings.cancelEdit(); }
        function test_navigation_typing_and_cancel() {
            control("signalSection").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_J);
            verify(control("signalDeviceName").activeFocus);
            keyClick(Qt.Key_A, Qt.ControlModifier);
            for (const letter of "hjkl") keyClick(letter);
            compare(control("signalDeviceName").text, "hjkl");
            keyClick(Qt.Key_Tab);
            verify(control("signalPrimary").activeFocus);
            keyClick(Qt.Key_Return);
            compare(backend.calls[backend.calls.length - 1].params.deviceName, "hjkl");
            compare(service.statusText, "Parowanie");
            keyClick(Qt.Key_Return);
            compare(service.linkAttempt, "");
            compare(service.qrModules.length, 0);
        }
        function test_qr_private_routing_expiry_and_destroy() {
            service.startLink("Putkin");
            const rows = Array(21).fill("100000000000000000001");
            backend.event("account.link.qr", {attemptId: "obsolete", modules: rows, expiresAtMs: Date.now() + 10000});
            compare(service.qrModules.length, 0);
            backend.event("account.link.qr", {attemptId: backend.linkAttempt, modules: rows, expiresAtMs: Date.now() + 10000});
            compare(service.qrModules.length, 21);
            compare(changes.count, 0);
            const qr = control("signalQr");
            verify(qr.visible);
            tryCompare(qr, "height", qr.width);
            tryCompare(qr, "available", true);
            wait(50);
            const image = grabImage(scene);
            const origin = qr.mapToItem(scene, 0, 0);
            const offset = Math.floor((qr.width - qr.extent) / 2);
            compare(image.pixel(origin.x + offset + 1, origin.y + offset + 1), Qt.rgba(1, 1, 1, 1));
            compare(image.pixel(origin.x + offset + 4 * qr.cellSize + 1, origin.y + offset + 4 * qr.cellSize + 1), Qt.rgba(0, 0, 0, 1));
            backend.event("account.link.qr", {attemptId: backend.linkAttempt, modules: rows, expiresAtMs: Date.now() + 100});
            tryVerify(() => service.qrModules.length === 0);
            // Only the backend owns cancellation/expiry of the process.
            service.cancelLink();
            service.startLink("Putkin");
            loader.item.section = "appearance";
            tryCompare(service, "linkAttempt", "");
        }
        function test_disable_and_confirm_local_history() {
            backend.accountState = "linked";
            backend.accountId = "synthetic-account";
            backend.serviceState = "ready";
            control("signalPrimary").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            compare(service.state, "disabled");
            control("signalRemoveHistory").forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return);
            verify(control("signalCancelDelete").activeFocus);
            verify(!backend.calls.some(call => call.method === "account.history.clear"));
            keyClick(Qt.Key_L); keyClick(Qt.Key_Return);
            compare(backend.calls[backend.calls.length - 1].method, "account.history.clear");
            compare(backend.calls[backend.calls.length - 1].params.confirm, "delete-local-history");
        }
        function test_live_both_accents_save_cancel() {
            const button = control("signalPrimary");
            waitForRendering(button);
            const original = grabImage(button);
            settings.setColor("accent", "#89b4fa");
            settings.setColor("accentSecondary", "#f38ba8");
            waitForRendering(button);
            const preview = grabImage(button);
            verify(!original.equals(preview));
            settings.cancelEdit();
            waitForRendering(button);
            verify(original.equals(grabImage(button)));
            settings.beginEdit();
            settings.setColor("accent", "#89b4fa");
            settings.setColor("accentSecondary", "#f38ba8");
            verify(settings.save());
            tryCompare(settings, "saving", false);
            settings.cancelEdit();
            waitForRendering(button);
            verify(preview.equals(grabImage(button)));
        }
        function test_state_labels_data() {
            return [
                {tag: "missing", state: "failed", account: "unlinked", error: "cli_unavailable", label: "Brak signal-cli"},
                {tag: "unlinked", state: "idle", account: "unlinked", error: "", label: "Niepołączony"},
                {tag: "linked", state: "ready", account: "linked", error: "", label: "Połączony"},
                {tag: "offline", state: "reconnecting", account: "linked", error: "transport_lost", label: "Offline"},
                {tag: "revoked", state: "failed", account: "relinkRequired", error: "relink_required", label: "Powiązanie niedostępne"}
            ];
        }
        function test_state_labels(data) {
            backend.accountState = data.account;
            backend.serviceState = data.state;
            backend.errorCode = data.error;
            compare(control("signalStatus").text, data.label);
        }
    }
}
