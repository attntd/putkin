import QtQuick

QtObject {
    id: root
    property bool automatic: true
    property bool present: true
    property bool enabled: true
    property int temperature: 4500
    property string owner: "42:100"
    property string failure: ""
    property var requests: []
    signal completed(int requestId, var result)
    function run(id: int, arguments: var): bool {
        const request = { id: id, arguments: arguments };
        requests = requests.concat([request]);
        if (automatic) Qt.callLater(() => root.deliver(request));
        return true;
    }
    function deliver(request: var): void {
        const args = request.arguments;
        let error = !present ? "absent" : failure;
        if (!error && args[0] === "set") {
            if (args[1] !== owner) error = "restart";
            else { enabled = args[2] === "on"; if (enabled) temperature = Number(args[3]); }
        }
        completed(request.id, { sample: error ? null : { enabled: enabled, temperature: temperature, owner: owner }, error: error });
    }
    function reset(): void {
        automatic = true; present = true; enabled = true; temperature = 4500;
        owner = "42:100"; failure = ""; requests = [];
    }
}
