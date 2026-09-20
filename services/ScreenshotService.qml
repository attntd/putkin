import QtQuick

QtObject {
    id: root
    required property var backend
    required property var screens
    property bool blocked: false
    property string phase: "idle"
    property var screen: null
    property string windowAddress: ""
    property rect selection: Qt.rect(0, 0, 0, 0)
    property var pending: null
    property url imageSource: ""
    property int imageWidth: 0
    property int imageHeight: 0
    property string lastError: ""
    property string savedPath: ""
    readonly property bool selecting: phase === "selecting"
    readonly property bool previewing: phase === "preview" || phase === "saving"
    readonly property bool hasSelection: selection.width > 0 && selection.height > 0
    readonly property string layout: screens.map(item => [item.name, item.x, item.y, item.width, item.height].join(":")).join("|")

    function start(window: var, monitor: string): bool {
        if (blocked || phase !== "idle" || backend.busy) return false;
        const target = monitor ? screens.find(item => item.name === monitor) : screens[0];
        if (!target) { lastError = qsTr("Brak ekranu do przechwycenia."); return false; }
        screen = target;
        // Copy the address, not a native object that focus changes can replace.
        windowAddress = window ? window.address : "";
        selection = Qt.rect(0, 0, 0, 0);
        imageSource = ""; savedPath = ""; lastError = ""; pending = null;
        phase = "selecting";
        return true;
    }
    function select(x1: real, y1: real, x2: real, y2: real): void {
        if (!selecting || !screen) return;
        const left = Math.floor(Math.max(0, Math.min(screen.width, Math.min(x1, x2))));
        const top = Math.floor(Math.max(0, Math.min(screen.height, Math.min(y1, y2))));
        const right = Math.ceil(Math.max(0, Math.min(screen.width, Math.max(x1, x2))));
        const bottom = Math.ceil(Math.max(0, Math.min(screen.height, Math.max(y1, y2))));
        selection = Qt.rect(left, top, right - left, bottom - top);
    }
    function confirm(window: bool): void {
        if (!selecting) return;
        if (window && !windowAddress) { lastError = qsTr("Brak okna aktywnego przed zrzutem."); return; }
        pending = {mode: window ? "window" : hasSelection ? "region" : "screen", screen: screen.name,
            window: windowAddress, region: [selection.x, selection.y, selection.width, selection.height]};
        phase = "hiding";
    }
    // Called by the host only after the native selection surface has unmapped.
    function unmapped(): void {
        if (phase !== "hiding") return;
        phase = "capturing";
        if (!backend.capture(pending)) { phase = "idle"; lastError = qsTr("Nie można rozpocząć zrzutu."); }
    }
    function save(): void {
        if (phase !== "preview") return;
        phase = "saving";
        lastError = "";
        backend.save();
    }
    function close(): void {
        phase = "idle"; pending = null; imageSource = "";
        backend.cancel();
    }
    onBlockedChanged: { if (blocked) close(); }
    onLayoutChanged: { if (phase === "selecting" || phase === "hiding" || phase === "capturing") close(); }
    readonly property Connections events: Connections {
        target: root.backend
        function onCaptured(source: string, width: int, height: int, error: string): void {
            if (root.phase !== "capturing") return;
            root.imageWidth = width; root.imageHeight = height; root.imageSource = source;
            root.phase = "preview";
            root.lastError = error;
        }
        function onSaved(path: string): void {
            if (root.phase !== "saving") return;
            root.savedPath = path;
            root.close();
        }
        function onFailed(error: string, fatal: bool): void {
            if (root.phase === "idle") return;
            if (root.phase === "saving" && !fatal) root.phase = "preview";
            else root.close();
            root.lastError = error;
        }
    }
}
