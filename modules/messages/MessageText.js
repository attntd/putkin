.pragma library

function escape(value) {
    return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/\n/g, "<br>");
}
function render(text, styles, mentions) {
    const points = [0, text.length];
    const ranges = styles.concat(mentions.map(m => ({start: m.start, length: m.length, style: "MENTION"})));
    for (const r of ranges) {
        if (r.start >= 0 && r.length > 0 && r.start + r.length <= text.length) points.push(r.start, r.start + r.length);
    }
    const cuts = Array.from(new Set(points)).sort((a, b) => a - b);
    let result = "";
    for (let i = 0; i + 1 < cuts.length; i++) {
        const start = cuts[i], end = cuts[i + 1];
        const active = ranges.filter(r => r.start <= start && r.start + r.length >= end).map(r => r.style);
        // Spoilers remain concealed; no implicit unmasking in a preview.
        let part = active.includes("SPOILER") ? "•••" : escape(text.slice(start, end));
        if (active.includes("BOLD") || active.includes("MENTION")) part = "<b>" + part + "</b>";
        if (active.includes("ITALIC")) part = "<i>" + part + "</i>";
        if (active.includes("STRIKETHROUGH")) part = "<s>" + part + "</s>";
        if (active.includes("MONOSPACE")) part = "<tt>" + part + "</tt>";
        result += part;
    }
    return result;
}
