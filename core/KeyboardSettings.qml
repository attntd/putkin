import QtQuick
import "Actions.js" as Actions

QtObject {
    id: root
    required property var storage
    required property var backend
    readonly property var catalog: Actions.catalog
    property var persisted: Actions.defaults()
    property var draft: Actions.copy(persisted)
    property bool editing: false
    property bool saving: false
    property bool checking: false
    property int checkGeneration: 0
    property bool conflict: false
    property string diskToken: ""
    property string baseToken: ""
    property string pendingText: ""
    property string readProblem: ""
    property string saveProblem: ""
    readonly property string validationProblem: Actions.problem(draft)
    readonly property string applyProblem: backend.lastError
    readonly property string problem: readProblem || saveProblem || (conflict ? qsTr("Plik klawiatury zmienił się. Wczytaj go ponownie.") : "") || validationProblem || applyProblem
    readonly property bool ready: diskToken !== ""
    readonly property bool canSave: editing && ready && !saving && !conflict && !readProblem && !validationProblem
    signal draftReplaced()

    function observe(): void {
        const value = storage.snapshot;
        if (!value || (saving && value.text === pendingText)) return;
        const changed = ready && value.token !== diskToken;
        diskToken = value.token;
        const parsed = value.missing ? {value: Actions.defaults()} : Actions.parse(value.text);
        readProblem = value.error ? qsTr("Nie można odczytać ustawień klawiatury.") : parsed.error || "";
        if (!readProblem) {
            persisted = parsed.value;
            backend.apply(persisted);
        }
        if (editing && changed) conflict = true;
        else if (!editing || !baseToken) replaceDraft();
    }
    function replaceDraft(): void {
        draft = Actions.copy(persisted); baseToken = diskToken; conflict = false; saveProblem = "";
        draftReplaced();
    }
    function beginEdit(): void { if (editing) return; replaceDraft(); editing = true; storage.refresh(); }
    function cancelEdit(): void {
        editing = false;
        if (checking || (saving && storage.cancelBeforeWrite())) { checkGeneration++; checking = false; saving = false; pendingText = ""; }
        replaceDraft();
    }
    function useLatest(): void { if (!saving) { replaceDraft(); storage.refresh(); } }
    function setBinding(action: string, field: string, value: string): void {
        if (!editing || saving || (field !== "shortcut" && field !== "command")) return;
        draft = draft.map(row => row.action === action ? Object.assign({}, row, {[field]: value}) : row);
        saveProblem = "";
    }
    function resetDraft(): void { if (editing && !saving) { draft = Actions.defaults(); draftReplaced(); } }
    function save(): bool {
        if (!canSave) return false;
        pendingText = Actions.serialize(draft); saveProblem = ""; saving = true; checking = true;
        backend.check(++checkGeneration, Actions.normalize(draft));
        return true;
    }
    function command(text: string): var {
        const row = persisted.find(item => item.command && item.command === text.trim().toLowerCase());
        return row ? {kind: "configuredCommand", id: row.command, action: row.action, title: Actions.find(row.action).title, subtitle: row.command, icon: ""} : null;
    }
    readonly property Connections fileChanges: Connections {
        target: root.storage
        function onSnapshotChanged(): void { root.observe(); }
        function onCommitted(text: string): void {
            root.persisted = Actions.parse(text).value; root.diskToken = "file:" + text;
            root.pendingText = ""; root.saving = false; root.readProblem = ""; root.replaceDraft();
            root.backend.apply(root.persisted);
        }
        function onFailed(reason: string): void {
            root.saving = false; root.pendingText = "";
            root.conflict = reason === "conflict" || reason === "verify";
            root.saveProblem = qsTr("Nie zapisano ustawień klawiatury: %1.").arg(reason);
        }
    }
    readonly property Connections backendChanges: Connections {
        target: root.backend
        function onChecked(generation: int, error: string): void {
            if (!root.checking || generation !== root.checkGeneration) return;
            root.checking = false;
            if (error) { root.saving = false; root.pendingText = ""; root.saveProblem = error; }
            else if (!root.storage.commit(root.pendingText, root.baseToken)) {
                root.saving = false; root.pendingText = ""; root.saveProblem = qsTr("Trwa inny zapis ustawień klawiatury.");
            }
        }
        function onReloaded(): void { if (root.ready && !root.readProblem) root.backend.apply(root.persisted); }
    }
    Component.onCompleted: observe()
}
