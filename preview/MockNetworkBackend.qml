import QtQuick

QtObject {
    id: root
    property bool available: true
    property bool wifiEnabled: true
    property bool hardwareEnabled: true
    property int connectivity: 4
    property bool connectivityCheckEnabled: true
    property string lastError: ""
    property string editorError: ""
    property bool confirmRadio: true
    property int radioCalls: 0
    property int checks: 0
    property int editorCalls: 0
    property var devices: [wifi, ethernet]
    readonly property MockNetworkDevice wifi: MockNetworkDevice {}
    readonly property MockNetworkDevice ethernet: MockNetworkDevice {
        type: 2
        name: "eth0"
    }
    readonly property MockNetwork home: MockNetwork {
        device: root.wifi
        name: "Dom"
        known: true
        state: 2
    }
    readonly property MockNetwork cafe: MockNetwork {
        device: root.wifi
        name: "Kawiarnia"
        security: 10
        signalStrength: 0.64
    }
    readonly property MockNetwork secure: MockNetwork {
        device: root.wifi
        name: "Nowa sieć"
        security: 3
        signalStrength: 0.45
    }
    readonly property MockNetwork enterprise: MockNetwork {
        device: root.wifi
        name: "Firma · 802.1X"
        security: 2
        signalStrength: 0.38
    }
    signal radioConfirmed
    signal radioFailed(string message)
    function setWifiEnabled(value: bool): void {
        radioCalls++;
        if (confirmRadio) {
            wifiEnabled = hardwareEnabled && value;
            radioConfirmed();
        }
    }
    function checkConnectivity(): void {
        checks++;
    }
    function openEditor(): void {
        editorCalls++;
        editorError = "Brak nm-connection-editor";
    }
    function reset(): void {
        available = true;
        wifiEnabled = true;
        hardwareEnabled = true;
        connectivity = 4;
        connectivityCheckEnabled = true;
        lastError = "";
        editorError = "";
        confirmRadio = true;
        radioCalls = 0;
        devices = [wifi, ethernet];
        ethernet.state = 4;
        wifi.nmManaged = true;
        wifi.state = 2;
        for (const item of [home, cafe, secure, enterprise]) {
            item.state = 4;
            item.automatic = true;
            item.rejectPsk = false;
            item.connects = 0;
            item.pskCalls = 0;
            item.disconnects = 0;
            item.known = item === home;
            item.passwordLength = 0;
        }
        home.state = 2;
        home.name = "Dom";
        wifi.networks.reset([home, cafe, secure, enterprise]);
    }
    Component.onCompleted: reset()
}
