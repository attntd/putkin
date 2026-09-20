import QtQuick

QtObject {
    // Empty: no wallpaper surfaces. "solid": neutral Mocha. Otherwise an
    // absolute local file path; never fetch network URLs or use reference PNGs.
    property string selection: ""
    readonly property bool enabled: selection.length > 0
    readonly property bool validPath: selection.startsWith("/") && !selection.includes("\n") && !selection.includes("\u0000")
    readonly property url source: validPath ? "file://" + selection.split("/").map(part => encodeURIComponent(part)).join("/") : ""
    readonly property string diagnostic: !enabled ? qsTr("Tapeta Putkin wyłączona") : selection === "solid" ? qsTr("Jednolite tło Mocha")
        : validPath ? "" : qsTr("Tapeta wymaga bezwzględnej ścieżki do pliku. Wyświetlono tło Mocha.")
}
