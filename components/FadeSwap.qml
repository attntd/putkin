import QtQuick

FadeScope {
    id: root
    property var value: null
    property bool requested: true
    property var displayedValue: null
    property bool revealing: false
    property bool initialized: false
    readonly property bool current: displayedValue === value && requested
    shown: requested && revealing
    contentKey: displayedValue

    // Retain the previous composed frame until its fade finishes. Model,
    // geometry and image sources change only while the section is transparent.
    function refresh(): void {
        if (!initialized) return;
        if (opacity === 0) Qt.callLater(present);
        else revealing = false;
    }
    function present(): void {
        if (!initialized || opacity !== 0) return;
        displayedValue = requested ? value : null;
        revealing = requested;
    }
    onValueChanged: refresh()
    onRequestedChanged: refresh()
    onOpacityChanged: { if (opacity === 0) Qt.callLater(present); }
    Component.onCompleted: { initialized = true; present(); }
    Component.onDestruction: initialized = false
}
