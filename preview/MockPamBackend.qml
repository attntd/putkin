import QtQuick
QtObject {
    property bool passwordBusy: false
    property int epoch: 0
    property bool enabled: false
    property string submitted: ""
    property int attempts: 0
    signal succeeded(int epoch, string method)
    signal failed(int epoch, string method)
    function begin(value: int): void { enabled = true; epoch = value; }
    function stop(): void { enabled = false; passwordBusy = false; submitted = ""; }
    function submit(value: int, text: string): bool {
        if (!enabled || passwordBusy || epoch !== value) return false;
        passwordBusy = true; submitted = text; ++attempts; return true;
    }
}
