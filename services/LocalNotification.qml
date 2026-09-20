import QtQuick

QtObject {
    readonly property bool internal: true
    property bool tracked: false
    property string appName: "Putkin"
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string image: ""
    property var actions: []
    property var hints: ({})
    property bool resident: false
    signal transientChanged()
    property int urgency: 2
    property int expireTimeout: 0
    signal closed(int reason)
    function expire(): void { closed(1); }
    function dismiss(): void { closed(2); }
}
