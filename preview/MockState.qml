import QtQml

QtObject {
    property int level: 60
    property bool selected: false

    function toggle(): void {
        selected = !selected;
    }

    function setLevel(next: real): void {
        level = Math.max(0, Math.min(100, Math.round(next)));
    }

    function reset(): void {
        level = 60;
        selected = false;
    }
}
