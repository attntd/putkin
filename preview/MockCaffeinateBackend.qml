import QtQuick

QtObject {
    property bool available: true
    property bool automatic: true
    property bool reject: false
    property bool busy: false
    property string mode: "off"
    property string errorText: ""
    property string pendingMode: "off"
    property var requests: []
    function request(value: string): bool {
        if (!available || busy) return false;
        requests = requests.concat([value]);
        busy = true;
        errorText = "";
        pendingMode = value;
        if (automatic) settle();
        return true;
    }
    function settle(): void {
        if (!reject) mode = pendingMode;
        else errorText = "Odmowa blokady usypiania.";
        busy = false;
    }
    function reset(): void {
        available = true; automatic = true; reject = false; busy = false;
        mode = "off"; pendingMode = "off"; errorText = ""; requests = [];
    }
}
