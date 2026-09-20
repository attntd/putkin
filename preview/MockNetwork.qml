import QtQuick
import "../services/NetworkValues.js" as Values

QtObject {
    id: root
    property string name: "Dom"
    property var device: null
    property bool known: false
    property int security: 3
    property real signalStrength: 0.8
    property int state: Values.disconnected
    readonly property bool connected: state === Values.connected
    readonly property bool stateChanging: state === Values.connecting || state === Values.disconnecting
    property int connects: 0
    property int pskCalls: 0
    property int disconnects: 0
    property int passwordLength: 0
    property bool automatic: true
    property bool rejectPsk: false
    signal connectionFailed(int reason)
    function connect(): void {
        connects++;
        state = Values.connecting;
        if (automatic) {
            if (known || security === Values.open) {
                state = Values.connected;
                device.state = Values.connected;
            } else {
                state = Values.disconnected;
                connectionFailed(Values.noSecrets);
            }
        }
    }
    function connectWithPsk(password: string): void {
        pskCalls++;
        passwordLength = password.length;
        state = Values.connecting;
        if (automatic) {
            if (rejectPsk) {
                state = Values.disconnected;
                connectionFailed(Values.noSecrets);
            } else {
                known = true;
                state = Values.connected;
                device.state = Values.connected;
            }
        }
    }
    function disconnect(): void {
        disconnects++;
        state = Values.disconnected;
        device.state = Values.disconnected;
    }
}
