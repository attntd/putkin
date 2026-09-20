.pragma library

// brightnessctl 0.5.1 CSV: device,class,current,rounded-percent,max.
// Ignore its rounded percentage; all calculations use the raw range.
function parse(output) {
    const lines = output.trim() ? output.trim().split(/\r?\n/) : [];
    const devices = [];
    for (const line of lines) {
        const fields = line.split(",");
        if (fields.length !== 5 || fields[1] !== "backlight"
                || !/^[A-Za-z0-9_][A-Za-z0-9_.:-]*$/.test(fields[0])
                || !/^\d+$/.test(fields[2]) || !/^\d+$/.test(fields[4]))
            return { error: "format", devices: [] };
        const current = Number(fields[2]), maximum = Number(fields[4]);
        if (maximum < 1 || maximum > 2147483647 || current > maximum)
            return { error: "range", devices: [] };
        if (devices.some(device => device.device === fields[0]))
            return { error: "format", devices: [] };
        devices.push({ device: fields[0], current: current, maximum: maximum });
    }
    // Prefer the finer range, then a stable name. Keep an existing selection
    // while it remains available; never let directory enumeration pick it.
    devices.sort((a, b) => b.maximum - a.maximum || (a.device < b.device ? -1 : a.device > b.device ? 1 : 0));
    return { error: "", devices: devices };
}

function raw(percent, maximum) {
    return Math.min(maximum, Math.max(1, Math.ceil(maximum / 100), Math.round(percent * maximum / 100)));
}
