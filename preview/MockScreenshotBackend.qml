import QtQuick

QtObject {
    property bool busy: false
    property var captures: []
    property int saves: 0
    property int cancels: 0
    signal captured(string source, int width, int height, string error)
    signal saved(string path)
    signal failed(string error, bool fatal)
    function capture(value: var): bool { captures = captures.concat([value]); busy = true; return true; }
    function save(): void { saves++; }
    function cancel(): void { cancels++; busy = false; }
}
