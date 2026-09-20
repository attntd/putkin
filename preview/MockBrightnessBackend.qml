import QtQuick

QtObject {
    id: root
    property var devices: [{ device: "test_backlight", current: 60, maximum: 100 }]
    property var requests: []
    property bool automatic: true
    property string writeError: ""
    property string readError: ""
    property bool ignoreWrites: false
    signal completed(int requestId, var result)

    function run(requestId: int, arguments: var): bool {
        const request = { id: requestId, arguments: arguments };
        requests = requests.concat([request]);
        if (automatic) Qt.callLater(() => root.deliver(request));
        return true;
    }
    function csv(values: var): string {
        return values.map(value => [value.device, "backlight", value.current, Math.round(value.current * 100 / value.maximum) + "%", value.maximum].join(",")).join("\n");
    }
    function deliver(request: var): void {
        const args = request.arguments;
        const setting = args.indexOf("set") >= 0;
        const deviceArg = args.find(arg => arg.indexOf("--device=") === 0);
        const name = deviceArg ? deviceArg.slice(9) : "";
        const values = name ? devices.filter(value => value.device === name) : devices;
        let error = setting ? writeError : readError;
        if (!error && (!values.length || (setting && values.length !== 1)))
            error = "Failed to read any devices of class 'backlight'.";
        if (setting && !error && !ignoreWrites)
            devices = devices.map(value => value.device === name ? Object.assign({}, value, { current: Number(args[args.length - 1]) }) : value);
        completed(request.id, { code: error ? 1 : 0, failure: "", error: error, output: setting ? "" : csv(values) });
    }
    function reset(): void {
        devices = [{ device: "test_backlight", current: 60, maximum: 100 }];
        requests = []; automatic = true; writeError = ""; readError = ""; ignoreWrites = false;
    }
}
