import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: root
    property var request: null
    property bool closing: false
    readonly property bool usingLua: Hyprland.usingLua
    readonly property bool busy: worker.running
    signal captured(string source, int width, int height, string error)
    signal saved(string path)
    signal failed(string error, bool fatal)

    function configure(): void {
        if (!Hyprland.usingLua) return;
        // No compositor fade can leave the selection visible in the capture.
        // Hyprland 0.56 updates rules by name, including after a shell reload.
        Hyprland.dispatch('function() hl.layer_rule({name="putkin-screenshot",match={namespace="^putkin-screenshot$"},'
            + 'no_anim=true,blur=false,dim_around=false}) end');
    }
    onUsingLuaChanged: configure()
    function capture(value: var): bool {
        if (busy) return false;
        const pictures = decodeURIComponent(StandardPaths.writableLocation(StandardPaths.PicturesLocation).toString().replace(/^file:\/\//, ""));
        request = Object.assign({}, value, {pictures: pictures});
        closing = false;
        worker.stdinEnabled = true;
        worker.running = true;
        deadline.restart();
        return true;
    }
    function save(): void {
        if (!busy || closing) { failed(qsTr("Podgląd zrzutu jest niedostępny."), true); return; }
        worker.write('{"op":"save"}\n');
        deadline.restart();
    }
    function cancel(): void {
        deadline.stop();
        closing = true;
        // SIGTERM unwinds the helper's temporary directory, also during grim.
        if (worker.running) worker.running = false;
    }
    function receive(line: string): void {
        if (closing) return;
        let data;
        try { data = JSON.parse(line); }
        catch (_) { cancel(); failed(qsTr("Niepoprawna odpowiedź adaptera zrzutu."), true); return; }
        deadline.stop();
        if (data.type === "captured") captured(data.source, data.width, data.height, data.error || "");
        else if (data.type === "saved") saved(data.path);
        else if (data.type === "error") failed(data.error, data.fatal === true);
    }
    readonly property Process worker: Process {
        command: ["python3", Quickshell.shellDir + "/services/screenshot_backend.py"]
        stdout: SplitParser { onRead: line => root.receive(line) }
        stderr: StdioCollector {}
        onStarted: write(JSON.stringify(root.request) + "\n")
    }
    readonly property Timer deadline: Timer {
        interval: 15000
        onTriggered: { root.cancel(); root.failed(qsTr("Upłynął czas wykonania zrzutu."), true); }
    }
    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void { if (event.name === "configreloaded") root.configure(); }
    }
    Component.onCompleted: {
        // ExitStatus is missing from the shipped Process qmltypes.
        worker.exited.connect(() => {
            deadline.stop();
            if (!closing) failed(qsTr("Adapter zrzutu zakończył pracę."), true);
        });
        configure();
    }
    Component.onDestruction: cancel()
}
