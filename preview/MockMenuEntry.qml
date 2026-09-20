import QtQml

QtObject {
    property string text: "Pozycja"
    property string icon: ""
    property bool enabled: true
    property bool isSeparator: false
    property bool hasChildren: false
    property int buttonType: 0
    property int checkState: Qt.Unchecked
    property int activations: 0
    readonly property MockObjectModel entries: MockObjectModel {}
    function triggered(): void { activations++; }
}
