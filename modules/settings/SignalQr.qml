import QtQuick

// The high contrast scan surface is data, not a second application palette.
Canvas {
    id: root
    property var modules: []
    readonly property int cellSize: Math.max(1, Math.floor(width / Math.max(1, modules.length + 8)))
    readonly property int extent: (modules.length + 8) * cellSize
    implicitWidth: 256
    implicitHeight: width
    canvasSize: Qt.size(width, height)
    onModulesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: { if (visible) requestPaint(); }
    onAvailableChanged: { if (available) requestPaint(); }
    onExtentChanged: requestPaint()
    onPaint: {
        const context = getContext("2d");
        context.reset();
        context.clearRect(0, 0, width, height);
        if (!modules.length) return;
        const offset = Math.floor((width - extent) / 2);
        context.fillStyle = "white";
        context.fillRect(offset, offset, extent, extent);
        context.fillStyle = "black";
        for (let y = 0; y < modules.length; y++)
            for (let x = 0; x < modules.length; x++)
                if (modules[y][x] === "1")
                    context.fillRect(offset + (x + 4) * cellSize, offset + (y + 4) * cellSize, cellSize, cellSize);
    }
}
