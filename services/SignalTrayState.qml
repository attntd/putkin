import QtQuick

// Signal Desktop's Linux SNI item stays Active. Its unread count is encoded
// in the red badge of IconPixmap (SystemTrayService, Signal 8.27.0).
// This invisible reader samples that badge on icon changes only. The visible
// icon is always a local, monochrome Material vector drawn by Glyph.
Canvas {
    id: root
    property string source: ""
    property bool attention: false
    property bool badge: false
    readonly property bool unread: attention || badge
    property string loadedSource: ""
    width: 32; height: 32
    // Stay attached to the render lifecycle so Canvas allocates its image;
    // opacity and disabled input keep the sampled bitmap off the visible UI.
    opacity: 0
    enabled: false
    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate

    function loadSource(): void {
        if (loadedSource && loadedSource !== source) unloadImage(loadedSource);
        loadedSource = source;
        if (!source) { badge = false; return; }
        if (!available) return;
        if (!isImageLoaded(source)) loadImage(source, Qt.size(32, 32));
        requestPaint();
    }
    function readBadge(): void {
        if (!available || !source) return;
        if (isImageError(source)) { badge = false; return; }
        if (!isImageLoaded(source)) return;
        const ctx = getContext("2d");
        if (!ctx) return;
        ctx.clearRect(0, 0, 32, 32);
        ctx.drawImage(source, 0, 0, 32, 32);
        const pixels = ctx.getImageData(0, 0, 32, 32).data;
        let red = 0;
        for (let y = 0; y < 16; ++y)
            for (let x = 16; x < 32; ++x) {
                const i = (y * 32 + x) * 4;
                if (pixels[i + 3] > 128 && pixels[i] > 170
                        && pixels[i] > pixels[i + 1] + 70 && pixels[i] > pixels[i + 2] + 70) ++red;
            }
        badge = red >= 8;
    }
    onSourceChanged: Qt.callLater(loadSource)
    onAvailableChanged: Qt.callLater(loadSource)
    onImageLoaded: requestPaint()
    onPaint: readBadge()
}
