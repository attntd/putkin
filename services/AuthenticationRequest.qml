import QtQuick

QtObject {
    id: root
    property string title: qsTr("Potwierdź operację")
    property string context: ""
    property string prompt: qsTr("Hasło")
    property string mode: "input"
    property string acceptText: qsTr("Potwierdź")
    property string rejectText: ""
    property string errorText: ""
    property string fingerprintState: "hidden"
    property real fingerprintProgress: 0
    property bool fingerprintCountdown: false
    property bool responseRequired: true
    property bool responseVisible: false
    property bool invalid: false
    property bool done: false
    property var identities: []
    property int identityIndex: 0
    signal answered(string response, bool accepted)
    signal identitySelected(int index)
    signal finished()
    signal released()
    function submit(response: string): void {
        if (done || !responseRequired) return;
        responseRequired = false;
        answered(response, true);
    }
    function cancel(): void { if (!done) { answered("", false); finish(); } }
    function reject(): void { cancel(); }
    function selectIdentity(index: int): void {
        if (!done && index >= 0 && index < identities.length && index !== identityIndex) {
            identityIndex = index;
            identitySelected(index);
        }
    }
    function finish(): void { if (!done) { done = true; finished(); } }
    function release(): void { released(); destroy(); }
}
