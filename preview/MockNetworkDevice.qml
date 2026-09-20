import QtQuick

QtObject {
    id: root
    property int type: 1
    property string name: "wlan0"
    property int state: 4
    property bool nmManaged: true
    property bool scannerEnabled: false
    property int scanStarts: 0
    property int scanStops: 0
    property int disconnects: 0
    readonly property MockObjectModel networks: MockObjectModel {}
    onScannerEnabledChanged: {
        if (scannerEnabled)
            scanStarts++;
        else
            scanStops++;
    }
    function disconnect(): void {
        disconnects++;
        state = 4;
        for (const network of networks.values)
            network.state = 4;
    }
}
