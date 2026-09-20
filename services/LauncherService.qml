import QtQuick
import "LauncherQuery.js" as Query

QtObject {
    id: root
    required property var backend
    property var workspaceService: null
    property var keyboard: null
    property var actions: null
    property string monitorName: ""
    property string commandMonitor: ""
    property var commandWindow: null
    property bool active: false
    property string text: ""
    property string chipMode: ""
    readonly property var parsed: Query.parse(text)
    readonly property string mode: chipMode || (Query.workspaceInput(text) ? "" : parsed.mode)
    readonly property string query: chipMode ? text.trim() : parsed.query
    readonly property bool commandInput: chipMode === "command" || (!mode && text.trim().startsWith(":"))
    readonly property string commandText: chipMode === "command" ? ":" + text.replace(/^:/, "") : text
    readonly property var command: commandInput ? Query.workspaceCommand(commandText) : null
    readonly property var results: commandInput ? commandResults()
        : Query.results(mode, query, Array.from(backend.applications), files, backend.clipboard, backend.history)
    readonly property bool historyView: mode === "recent" || (!query && !mode) || (!query && mode === "file")
    property var files: []
    property int revision: 0
    property bool searching: false
    property bool busy: false
    property int request: 0
    property int generation: 0
    property int actionGeneration: -1
    property bool workspaceAction: false
    property string lastError: ""
    property string previewId: ""
    property string previewText: ""
    property string previewImage: ""
    property int previewRevision: 0
    signal activated()
    signal focusRequested()

    function previewEntry(entry: var): void {
        const key = active && backend.ready && entry && entry.kind === "clipboard" ? entry.id : "";
        if (key === previewId) return;
        previewId = key;
        previewText = "";
        previewImage = "";
        previewRevision++;
        backend.preview(previewRevision, key);
    }



    function startMode(value: string): void {
        generation++;
        chipMode = value === "clipboard" ? "clipboard" : value === "commands" ? "command" : "";
        text = "";
        lastError = "";
        reportError();
        focusRequested();
    }

    function commandResults(): var {
        if (!command) {
            const configured = keyboard ? keyboard.command(commandText) : null;
            return configured ? [configured] : [];
        }
        return [Object.assign({}, command, {
            title: (command.action === "move" ? qsTr("Przenieś okno do workspace %1") : qsTr("Przejdź do workspace %1")).arg(command.workspaceId),
            subtitle: command.id, icon: ""
        })];
    }
    function edit(value: string): void {
        const prefix = Query.parse(value);
        if (chipMode === "command" && /^:[afc]\s+/i.test(value)) {
            chipMode = prefix.mode; text = value.replace(/^:[afc]\s+/i, "");
        } else if (!chipMode && prefix.committed) {
            chipMode = prefix.mode;
            text = value.replace(/^:[afc]?\s+/i, "");
        } else text = value;
    }
    function removeFilter(restorePrefix: bool): void {
        const prefix = chipMode === "command" ? ":" : Query.prefix(chipMode);
        chipMode = "";
        if (restorePrefix) text = prefix;
    }
    function setActive(value: bool): void {
        if (active === value) return;
        generation++;
        active = value;
        previewEntry(null);
        if (value) {
            chipMode = ""; text = ""; lastError = "";
            commandMonitor = monitorName || (workspaceService ? workspaceService.focusedMonitorName : "");
            commandWindow = workspaceService ? workspaceService.activeWindow : null;
        } else commandWindow = null;
        backend.setVisible(value);
        schedule();
        if (value) reportError();
    }
    function reportError(): void {
        if (!active || commandInput) return;
        const problem = backend.lastError || (mode === "clipboard" ? backend.clipboardError : "")
            || (historyView ? backend.historyError : "");
        if (problem) lastError = problem;
    }
    function schedule(): void {
        revision++;
        debounce.stop();
        files = [];
        searching = active && !commandInput && (!mode || mode === "file") && query.length > 0;
        // Cancel an old fd process immediately, including when the panel closes.
        backend.search(-revision, "");
        if (searching && backend.ready) debounce.restart();
    }
    function activate(entry: var): bool {
        if (!entry || !active || busy) return false;
        if (entry.kind === "configuredCommand") {
            const current = keyboard ? keyboard.command(commandText) : null;
            if (!commandInput || !current || current.action !== entry.action || current.id !== entry.id || !actions) return false;
            const accepted = actions.invoke(entry.action, commandWindow, commandMonitor);
            if (accepted) activated();
            else lastError = actions.lastError;
            return accepted;
        }
        if (entry.kind === "workspaceCommand") {
            if (!command || entry.id !== command.id) return false;
            lastError = "";
            if (!workspaceService) { lastError = qsTr("Hyprland niedostępny"); return false; }
            request++;
            actionGeneration = generation;
            // A workspace already at its destination can finish synchronously.
            workspaceAction = true;
            busy = true;
            const accepted = workspaceService.executeCommand(request, command.action, command.workspaceId, commandWindow, commandMonitor);
            if (!accepted) {
                busy = false; workspaceAction = false;
                lastError = workspaceService.lastError;
            }
            return accepted;
        }
        if (!backend.ready || commandInput) return false;
        lastError = "";
        request++;
        actionGeneration = generation;
        busy = backend.activate(request, entry);
        if (busy) actionDeadline.restart();
        return busy;
    }
    function finish(value: int, error: string): void {
        if (value !== request || !busy) return;
        actionDeadline.stop();
        busy = false;
        workspaceAction = false;
        if (error) lastError = error;
        else if (active && generation === actionGeneration) activated();
    }
    onModeChanged: { schedule(); reportError(); }
    onQueryChanged: schedule()
    onCommandInputChanged: schedule()
    readonly property Timer debounce: Timer {
        interval: 140
        onTriggered: root.backend.search(root.revision, root.query)
    }
    readonly property Timer actionDeadline: Timer {
        interval: 12000
        onTriggered: { root.busy = false; root.request++; root.lastError = "Launcher nie potwierdził operacji."; }
    }
    readonly property Connections changes: Connections {
        target: root.backend
        function onReadyChanged(): void { if (!root.backend.ready) root.previewEntry(null); root.schedule(); root.reportError(); }
        function onLastErrorChanged(): void { if (!root.backend.ready && !root.workspaceAction) { root.busy = false; root.actionDeadline.stop(); } root.reportError(); }
        function onClipboardErrorChanged(): void { root.reportError(); }
        function onHistoryErrorChanged(): void { root.reportError(); }
        function onSearched(value: int, entries: var, error: string): void {
            if (value !== root.revision || !root.active || root.debounce.running) return;
            root.files = entries;
            root.searching = false;
            if (error) root.lastError = error;
        }
        function onActivated(value: int, error: string): void {
            if (!root.workspaceAction) root.finish(value, error);
        }
        function onPreviewed(value: int, key: string, text: string, image: string, error: string): void {
            if (!root.active || value !== root.previewRevision || key !== root.previewId) return;
            root.previewText = text;
            root.previewImage = image;
            if (error) root.lastError = error;
        }
    }
    readonly property Connections workspaceChanges: Connections {
        target: root.workspaceService
        function onCommandFinished(value: int, error: string): void {
            if (root.workspaceAction) root.finish(value, error);
        }
    }
}
