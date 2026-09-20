.pragma library

function workspaceCommand(text) {
    const match = text.trim().match(/^:(mw|w)([0-9])$/i);
    if (!match) return null;
    const digit = Number(match[2]);
    return { kind: "workspaceCommand", id: ":" + match[1].toLowerCase() + match[2],
        action: match[1].toLowerCase() === "mw" ? "move" : "switch",
        workspaceId: digit === 0 ? 10 : digit };
}

function workspaceInput(text) { return text === ":" || /^:(?:mw|w)/i.test(text.trim()); }

function parse(text) {
    const match = text.match(/^:([afc]?)(?:\s+([\s\S]*))?$/i);
    if (!match)
        return { mode: "", query: text.trim(), committed: false };
    return { mode: ({ a: "application", f: "file", c: "clipboard" })[match[1].toLowerCase()] || "recent",
        query: (match[2] || "").trim(), committed: /^:[afc]?\s/i.test(text) };
}

function prefix(mode) {
    return ({ application: ":a", file: ":f", clipboard: ":c", recent: ":" })[mode] || "";
}

function normalized(value) {
    return typeof value === "string" ? value.toLocaleLowerCase() : "";
}

function wordStartsWith(value, query) {
    return value.split(/[\s._\-/]+/).some(word => word.startsWith(query));
}

function applicationRelevance(application, query) {
    const name = normalized(application.name);
    const generic = normalized(application.genericName);
    const comment = normalized(application.comment);
    const keywords = application.keywords ? normalized(application.keywords.join(" ")) : "";
    if (name === query) return 0;
    if (name.startsWith(query)) return 1;
    if (wordStartsWith(name, query)) return 2;
    if (name.indexOf(query) >= 0) return 3;
    if (generic === query || generic.startsWith(query)) return 4;
    if (wordStartsWith(generic, query)) return 5;
    if (wordStartsWith(keywords, query)) return 6;
    if (generic.indexOf(query) >= 0 || keywords.indexOf(query) >= 0) return 7;
    if (comment.indexOf(query) >= 0) return 8;
    return 100;
}

function applicationResult(app) {
    return { kind: "application", id: app.id, title: app.name,
        subtitle: app.genericName || app.comment || "", icon: app.icon || "", application: app };
}

function fileResult(path) {
    return { kind: "file", id: path, title: path.slice(path.lastIndexOf("/") + 1), subtitle: path, icon: "" };
}

function clipboardResult(entry) {
    return { kind: "clipboard", id: entry.id, title: entry.preview, subtitle: "", icon: "", binary: entry.binary };
}

function results(mode, text, applications, files, clipboard, history) {
    const query = normalized(text);
    const apps = applications.filter(app => app && !app.noDisplay);
    if (mode === "recent" || (!query && mode !== "clipboard")) {
        const byId = new Map(apps.map(app => [app.id, app]));
        const clips = new Map(clipboard.map(entry => [entry.id, entry]));
        const recent = history.filter(record => !mode || mode === "recent" || record.kind === mode).map(record => {
            if (record.kind === "application") {
                const app = byId.get(record.id);
                return app ? applicationResult(app) : null;
            }
            if (record.kind === "file") return fileResult(record.id);
            const entry = clips.get(record.id);
            return entry ? clipboardResult(entry) : null;
        }).filter(result => result && (!query || (result.kind === "application"
            ? applicationRelevance(result.application, query) < 100
            : normalized(result.title + " " + result.subtitle).indexOf(query) >= 0)));
        if (mode === "application" && !query) {
            const used = new Set(recent.map(entry => entry.id));
            return recent.concat(apps.filter(app => !used.has(app.id)).sort((a, b) => a.name.localeCompare(b.name)).map(applicationResult));
        }
        return recent;
    }
    let matches = [];
    if (!mode || mode === "application") {
        const ranked = apps.filter(app => applicationRelevance(app, query) < 100);
        ranked.sort((a, b) => applicationRelevance(a, query) - applicationRelevance(b, query)
            || a.name.localeCompare(b.name));
        matches = ranked.map(applicationResult);
    }
    if (!mode || mode === "file") matches = matches.concat(files.map(fileResult));
    if (!mode || mode === "clipboard") matches = matches.concat(clipboard.filter(entry =>
        normalized(entry.preview).indexOf(query) >= 0).map(clipboardResult));
    return matches;
}
