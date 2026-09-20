.pragma library

// Verify the actual painted pixels, including antialiasing: every pixel must
// be a blend of one themed foreground and the known background.
function verifyIcon(test, scene, icon, background, paintArea) {
    test.tryCompare(icon, "ready", true);
    // A reactive update may already have rendered before tryCompare returns.
    // Settle layout and capture its current pixels instead of requiring another frame.
    test.verify(test.waitForPolish(scene), "Unsettled layout for " + icon.symbol);
    const image = test.grabImage(scene);
    const ratio = icon.pixelRatio;
    const area = paintArea || icon;
    const origin = area.mapToItem(scene, 0, 0);
    const foreground = icon.color;
    let ink = 0, peak = 0;
    for (let y = Math.ceil(origin.y * ratio); y < Math.floor((origin.y + area.height) * ratio); ++y) {
        for (let x = Math.ceil(origin.x * ratio); x < Math.floor((origin.x + area.width) * ratio); ++x) {
            const pixel = image.pixel(x, y);
            const alpha = (pixel.b - background.b) / (foreground.b - background.b);
            peak = Math.max(peak, alpha);
            test.verify(alpha > -0.025 && alpha < 1.025, "Unexpected pixel color in " + icon.symbol);
            test.verify(Math.abs(pixel.r - (background.r + alpha * (foreground.r - background.r))) < 0.015,
                "Multiple red shades in " + icon.symbol);
            test.verify(Math.abs(pixel.g - (background.g + alpha * (foreground.g - background.g))) < 0.015,
                "Multiple green shades in " + icon.symbol);
            if (alpha > 0.2) ++ink;
        }
    }
    // Thin curved strokes at 20 px can be entirely antialiased (fingerprint
    // peaks at 0.86 coverage). Require visible ink and high coverage instead
    // of fully covered pixel centers; the one-color checks above remain strict.
    test.verify(ink > 8 && peak > 0.8, "Missing or undersized painted icon: " + icon.symbol
        + " (ink=" + ink + ", peak=" + peak + ")");
}
