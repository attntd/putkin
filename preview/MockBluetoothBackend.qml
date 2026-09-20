import QtQuick

QtObject {
    id: root
    property bool available: true
    property bool busy: false
    property bool managerBusy: false
    property bool managerAvailable: false
    property string managerError: ""
    property string lastError: ""
    property var adapters: [internal]
    property var calls: []
    property var operation: null
    property bool automatic: true
    property int managerCalls: 0
    signal completed(int serial, string error)
    signal managerRequested
    readonly property MockBluetoothAdapter internal: MockBluetoothAdapter {}
    readonly property MockBluetoothAdapter usb: MockBluetoothAdapter { name: "Bluetooth USB"; adapterId: "hci1" }
    readonly property MockBluetoothDevice headphones: MockBluetoothDevice { adapter: root.internal; connected: true; batteryAvailable: true }
    readonly property MockBluetoothDevice keyboard: MockBluetoothDevice { adapter: root.internal; name: "Klawiatura"; address: "00:11:22:33:44:66" }
    readonly property MockBluetoothDevice nearby: MockBluetoothDevice { adapter: root.internal; name: "Niesparowane"; address: "00:11:22:33:44:77"; paired: false }
    readonly property MockBluetoothDevice mouse: MockBluetoothDevice { adapter: root.usb; name: "Mysz USB"; address: "00:11:22:33:44:88" }
    function request(kind: string, target: var, value: bool, serial: int): bool {
        if (busy || !available) return false;
        const op = {kind: kind, target: target, value: value, id: serial};
        calls = calls.concat([op]);
        operation = op;
        busy = true;
        if (automatic) settle(op, true, "");
        return true;
    }
    function settle(op: var, update: bool, error: string): void {
        if (update && !error) {
            if (op.kind === "radio") op.target.enabled = op.value;
            else op.target.connected = op.value;
        }
        if (operation === op) { operation = null; busy = false; }
        completed(op.id, error);
    }
    function cancel(serial: int): void {
        if (operation && operation.id === serial) { operation = null; busy = false; }
    }
    function openManager(): void {
        managerCalls++;
        managerError = managerAvailable ? "" : "Brak blueman-manager. Zainstaluj Blueman, aby parować nowe urządzenia.";
        if (managerAvailable) managerRequested();
    }
    function reset(): void {
        available = true; busy = false; automatic = true; operation = null;
        lastError = ""; managerError = ""; managerAvailable = false; managerCalls = 0;
        internal.enabled = true; internal.state = 1; usb.enabled = true;
        headphones.connected = true; keyboard.connected = false; mouse.connected = false;
        headphones.paired = true; keyboard.paired = true; nearby.paired = false;
        headphones.name = "Słuchawki"; headphones.batteryAvailable = true; headphones.battery = 0.72;
        headphones.blocked = false; keyboard.blocked = false;
        internal.devices.reset([headphones, keyboard, nearby]); usb.devices.reset([mouse]);
        adapters = [internal]; calls = [];
    }
    Component.onCompleted: reset()
}
