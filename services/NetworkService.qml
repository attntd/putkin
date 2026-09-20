import QtQuick
import "NetworkValues.js" as Values

QtObject {
    id: root
    required property var backend
    readonly property bool available: backend.available
    readonly property var devices: available ? backend.devices : []
    readonly property var wifiDevices: devices.filter(device => device.type === Values.wifi)
    readonly property var scannableDevices: wifiDevices.filter(device => device.nmManaged)
    readonly property var ethernetDevices: devices.filter(device => device.type === Values.wired)
    readonly property bool wifiEnabled: available && backend.wifiEnabled
    readonly property bool hardwareEnabled: available && backend.hardwareEnabled
    readonly property bool canScan: available && wifiEnabled && hardwareEnabled && !(radioBusy && !radioTarget) && scannableDevices.length > 0
    readonly property bool ethernetConnected: ethernetDevices.some(device => device.state === Values.connected)
    readonly property var activeWifi: {
        if (!wifiEnabled || !hardwareEnabled)
            return [];
        const result = [];
        for (const device of wifiDevices)
            for (const network of device.networks.values)
                if (network.connected)
                    result.push(network);
        return result;
    }
    readonly property string internetText: !available ? qsTr("Sieć niedostępna") : !backend.connectivityCheckEnabled ? qsTr("Internet · stan nieznany") : [qsTr("Internet · stan nieznany"), qsTr("Brak dostępu do internetu"), qsTr("Portal logowania"), qsTr("Ograniczony dostęp do internetu"), qsTr("Dostęp do internetu")][backend.connectivity] || qsTr("Internet · stan nieznany")
    readonly property string wifiText: !available ? (backend.lastError || qsTr("NetworkManager niedostępny")) : !wifiDevices.length ? qsTr("Brak adaptera Wi-Fi") : !hardwareEnabled ? qsTr("Wi-Fi zablokowane sprzętowo") : !wifiEnabled ? qsTr("Wi-Fi wyłączone") : !wifiDevices.some(device => device.nmManaged) ? qsTr("Wi-Fi poza kontrolą NetworkManagera") : activeWifi.length ? activeWifi.map(network => label(network)).join(", ") : qsTr("Wi-Fi niepołączone")
    readonly property string statusText: (ethernetConnected ? qsTr("Ethernet · połączony") + "\n" : "") + wifiText + "\n" + internetText
    readonly property string indicator: !available ? "—" : ethernetConnected ? "LAN" : activeWifi.length ? "Wi-Fi" : "×"
    property string lastError: ""
    property bool radioBusy: false
    property bool radioTarget: false
    property int radioTimeout: 4000
    property int actionTimeout: 30000
    property var target: null
    property string phase: ""
    property int serial: 0
    readonly property bool busy: phase === "connecting" || phase === "disconnecting"
    readonly property bool needsPassword: phase === "password" && target !== null
    readonly property bool targetPresent: !!target && wifiDevices.indexOf(target.device) >= 0 && target.device.networks.values.indexOf(target) >= 0
    property var scanOwners: []
    property var ownedScanners: []
    readonly property int scanRequests: scanOwners.length

    function label(network: var): string {
        return network && network.name.length ? network.name.replace(/[\r\n\t\u2028\u2029]/g, " ") : qsTr("Sieć bez nazwy");
    }
    function securityText(network: var): string {
        return Values.securityName(network.security);
    }
    function supportsPsk(network: var): bool {
        return !!network && Values.supportsPsk(network.security);
    }
    function canConnect(network: var): bool {
        // 0.3.1 reports saved open profiles without a security group as Unknown.
        return !!network && (network.security === Values.open || supportsPsk(network)
            || (network.known && network.security === Values.unknownSecurity));
    }
    function acquireScan(owner: var): void {
        if (scanOwners.indexOf(owner) < 0)
            scanOwners = scanOwners.concat([owner]);
        syncScans();
    }
    function releaseScan(owner: var): void {
        scanOwners = scanOwners.filter(item => item !== owner);
        syncScans();
    }
    function syncScans(): void {
        const wanted = canScan && scanOwners.length ? scannableDevices : [];
        const retained = [];
        for (const device of ownedScanners) {
            if (!device)
                continue;
            if (wanted.indexOf(device) >= 0)
                retained.push(device);
            else
                device.scannerEnabled = false;
        }
        for (const device of wanted) {
            // Never switch off a scanner that was already owned elsewhere.
            if (retained.indexOf(device) < 0 && !device.scannerEnabled) {
                retained.push(device);
                device.scannerEnabled = true;
            }
        }
        ownedScanners = retained;
    }
    function setWifiEnabled(value: bool): bool {
        if (!available || !wifiDevices.length || radioBusy)
            return false;
        lastError = "";
        if (value && !hardwareEnabled) {
            lastError = qsTr("Odblokuj sprzętowy przełącznik Wi-Fi");
            return false;
        }
        if (!value)
            cancel();
        radioTarget = value;
        radioBusy = true;
        radioDeadline.restart();
        backend.setWifiEnabled(value);
        return true;
    }
    function confirmRadio(): void {
        if (radioBusy && wifiEnabled === radioTarget && (!radioTarget || hardwareEnabled)) {
            radioBusy = false;
            radioDeadline.stop();
        }
    }
    function invalidate(): void {
        if (target && (!canScan || scannableDevices.indexOf(target.device) < 0))
            cancel();
        if (radioBusy && (!available || !wifiDevices.length || (radioTarget && !hardwareEnabled))) {
            radioBusy = false;
            radioDeadline.stop();
            lastError = wifiText;
        }
        syncScans();
    }
    function cancel(): void {
        const previous = target;
        const wasBusy = busy;
        serial++;
        actionDeadline.stop();
        phase = "";
        target = null;
        if (previous && wasBusy && available && wifiDevices.indexOf(previous.device) >= 0)
            previous.device.disconnect();
    }
    function activate(network: var): bool {
        if (!canScan || !network || !network.device.nmManaged || wifiDevices.indexOf(network.device) < 0)
            return false;
        if (busy && target === network)
            return false;
        cancel();
        lastError = "";
        if (!network.connected && !canConnect(network)) {
            lastError = qsTr("Ta sieć wymaga zewnętrznego edytora połączeń");
            return false;
        }
        target = network;
        phase = network.connected ? "disconnecting" : "connecting";
        actionDeadline.restart();
        if (phase === "disconnecting")
            network.disconnect();
        else
            network.connect(); // Always try saved credentials first.
        observe();
        return true;
    }
    function providePsk(network: var, operation: int, password: string): bool {
        if (operation !== serial || target !== network || !needsPassword || !targetPresent || !canScan || !supportsPsk(network))
            return false;
        if (!password.length) {
            lastError = qsTr("Wpisz hasło sieci");
            return false;
        }
        lastError = "";
        phase = "connecting";
        actionDeadline.restart();
        network.connectWithPsk(password);
        return true;
    }
    function failed(reason: int): void {
        if (phase !== "connecting" || !target)
            return;
        actionDeadline.stop();
        if (reason === Values.noSecrets && supportsPsk(target)) {
            phase = "password";
            lastError = qsTr("Podaj hasło lub popraw odrzucone hasło");
        } else {
            phase = "";
            lastError = reason === 4 ? qsTr("Przekroczono czas uwierzytelniania") : reason === 5 ? qsTr("Sieć zniknęła z zasięgu") : reason === Values.noSecrets ? qsTr("Dane logowania wymagają zewnętrznego edytora") : qsTr("Nie udało się połączyć z siecią");
            target = null;
        }
    }
    function observe(): void {
        if (!target)
            return;
        if ((phase === "connecting" && target.connected) || (phase === "disconnecting" && target.state === Values.disconnected)) {
            actionDeadline.stop();
            phase = "";
            target = null;
        }
    }
    function openEditor(): void {
        backend.openEditor();
    }
    function checkInternet(): void {
        backend.checkConnectivity();
    }

    onCanScanChanged: invalidate()
    onTargetChanged: {
        if (!target && phase.length) {
            actionDeadline.stop(); phase = ""; serial++;
            lastError = qsTr("Wybrana sieć jest już niedostępna");
        }
    }
    onWifiDevicesChanged: invalidate()
    onScannableDevicesChanged: invalidate()
    onAvailableChanged: invalidate()
    onHardwareEnabledChanged: invalidate()
    onTargetPresentChanged: {
        if (target && !targetPresent) {
            cancel();
            lastError = qsTr("Wybrana sieć jest już niedostępna");
        }
    }
    readonly property Connections radioChanges: Connections {
        target: root.backend
        function onRadioConfirmed(): void {
            root.confirmRadio();
        }
        function onRadioFailed(message: string): void {
            root.radioBusy = false;
            root.radioDeadline.stop();
            root.lastError = message;
        }
    }
    readonly property Connections targetChanges: Connections {
        target: root.target
        function onConnectionFailed(reason: int): void {
            root.failed(reason);
        }
        function onStateChanged(): void {
            root.observe();
        }
        function onConnectedChanged(): void {
            root.observe();
        }
    }
    readonly property Timer radioDeadline: Timer {
        interval: root.radioTimeout
        onTriggered: {
            root.radioBusy = false;
            root.lastError = qsTr("Nie potwierdzono zmiany radia. Sprawdź uprawnienia i rfkill.");
        }
    }
    readonly property Timer actionDeadline: Timer {
        interval: root.actionTimeout
        onTriggered: {
            root.cancel();
            root.lastError = qsTr("Przekroczono czas operacji sieciowej");
        }
    }
    Component.onDestruction: {
        cancel();
        for (const device of ownedScanners)
            if (device)
                device.scannerEnabled = false;
    }
}
