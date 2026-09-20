import QtQml

QtObject {
    objectName: "mock"
    property string title: "Aplikacja"
    property string tooltipTitle: title
    property string tooltipDescription: "Stan aplikacji"
    property string icon: ""
    property int status: 1
    property bool hasMenu: menu !== null
    property bool onlyMenu: false
    property var menu: null
    property int activations: 0
    property int secondaryActivations: 0
    function activate(): void { activations++; }
    function secondaryActivate(): void { secondaryActivations++; }
}
