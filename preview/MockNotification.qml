import QtQuick

QtObject {
    id: root
    required property int notificationId
    property bool tracked: false
    property bool lastGeneration: false
    property string appName: "Putkin"
    property string appIcon: ""
    property string summary: "Powiadomienie testowe"
    property string body: ""
    property string image: ""
    property real expireTimeout: -1
    property int urgency: 1
    property bool resident: false
    // `transient` is reserved in QML declarations (native objects expose it).
    property bool isTransient: false
    signal transientChanged()
    onIsTransientChanged: transientChanged()
    property var hints: ({})
    property var actions: []
    property int closeReason: 0
    signal closed(int reason)
    signal invoked(string identifier)
    function close(reason: int): void { if (!closeReason) { closeReason = reason; tracked = false; closed(reason); } }
    function expire(): void { close(1); }
    function dismiss(): void { close(2); }
    function requestClose(): void { close(3); }
    function setActions(values: var): void {
        actions = values.map(value => ({identifier: value[0], text: value[1], invoke: () => {
            if (root.closeReason) return;
            root.invoked(value[0]);
            if (!root.resident) root.dismiss();
        }}));
    }
}
