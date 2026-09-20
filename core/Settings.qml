import QtQuick
import "Appearance.js" as Appearance

QtObject {
    id: root
    required property var storage
    property var keyboard: null
    property var persisted: Appearance.defaults()
    property var draft: Appearance.copy(persisted.appearance)
    property var preview: Appearance.copy(persisted.appearance)
    readonly property var effective: editing ? preview : persisted.appearance
    property bool editing: false
    property bool saving: false
    property bool conflict: false
    property string readProblem: ""
    property string saveProblem: ""
    property string notice: ""
    property string diskToken: ""
    property string baseToken: ""
    property string pendingText: ""
    readonly property bool ready: diskToken !== ""
    readonly property bool valid: Appearance.isHex(draft.accent) && Appearance.isHex(draft.accentSecondary)
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(persisted.appearance)
    readonly property bool canSave: editing && ready && valid && !saving && !conflict && readProblem === ""
    signal draftReplaced()
    property string validationProblem: ""
    readonly property string conflictProblem: conflict ? qsTr("Plik ustawień zmienił się. Wczytaj go ponownie przed zapisem.") : ""

    function describe(error: string): string {
        if (error === "json") return qsTr("Plik ustawień zawiera niepoprawny JSON. Popraw go poza Putkin; zachowano ostatni poprawny motyw.");
        if (error === "version") return qsTr("Nieobsługiwana wersja ustawień. Ta wersja Putkin nie nadpisze pliku.");
        if (error === "unknown") return qsTr("Plik zawiera nieznane opcje. Zapis zablokowany, aby ich nie utracić.");
        return qsTr("Niepoprawne ustawienia w pliku. Sprawdź kolory #RRGGBB.");
    }
    function observe(): void {
        const observed = storage.snapshot;
        if (!observed) return;
        // Verification of our own write cannot promote state before committed.
        if (saving && !observed.error && !observed.missing && observed.text === pendingText)
            return;
        const initial = !ready;
        const changed = !initial && observed.token !== diskToken;
        diskToken = observed.token;
        readProblem = "";
        if (observed.error)
            readProblem = qsTr("Nie można odczytać ustawień: %1. Zachowano ostatni poprawny motyw.").arg(observed.error);
        else {
            const parsed = observed.missing ? {value: Appearance.defaults()} : Appearance.parse(observed.text);
            if (parsed.error) readProblem = describe(parsed.error);
            else persisted = parsed.value;
        }
        if (editing && changed) {
            conflict = true;
            notice = "";
        } else if (editing && initial) {
            replaceDraft();
        }
    }
    function replaceDraft(): void {
        draft = Appearance.copy(persisted.appearance);
        preview = Appearance.copy(draft);
        baseToken = diskToken;
        conflict = false;
        saveProblem = "";
        notice = "";
        draftReplaced();
    }
    function beginEdit(): void {
        if (editing) return;
        replaceDraft();
        editing = true;
        if (keyboard) keyboard.beginEdit();
        storage.refresh();
    }
    function cancelEdit(): void {
        editing = false;
        if (keyboard) keyboard.cancelEdit();
        if (saving && storage.cancelBeforeWrite()) {
            saving = false;
            pendingText = "";
        }
        replaceDraft();
    }
    function useLatest(): void {
        if (saving) return;
        replaceDraft();
        storage.refresh();
    }
    function setColor(key: string, value: string): void {
        if (!editing || saving || (key !== "accent" && key !== "accentSecondary")) return;
        const next = Appearance.copy(draft);
        next[key] = value;
        draft = next;
        if (Appearance.isHex(value)) {
            const colors = Appearance.copy(preview);
            colors[key] = value.toLowerCase();
            preview = colors;
        }
        notice = "";
    }
    function resetDraft(): void {
        if (!editing || saving) return;
        draft = Appearance.defaults().appearance;
        preview = Appearance.copy(draft);
        notice = qsTr("Przywrócono domyślne w podglądzie. Zapisz, aby je zachować.");
        draftReplaced();
    }
    function save(): bool {
        if (!canSave) return false;
        pendingText = Appearance.serialize(draft);
        saveProblem = "";
        notice = "";
        saving = true;
        if (!storage.commit(pendingText, baseToken)) {
            saving = false;
            saveProblem = qsTr("Trwa inny zapis. Spróbuj ponownie.");
            return false;
        }
        return true;
    }
    readonly property Connections changes: Connections {
        target: root.storage
        function onSnapshotChanged(): void { root.observe(); }
        function onCommitted(text: string): void {
            root.persisted = Appearance.parse(text).value;
            root.diskToken = "file:" + text;
            root.saving = false;
            root.pendingText = "";
            root.readProblem = "";
            root.replaceDraft();
            root.notice = qsTr("Zapisano ustawienia.");
        }
        function onFailed(reason: string): void {
            root.saving = false;
            root.pendingText = "";
            if (reason === "conflict") root.conflict = true;
            root.saveProblem = reason === "conflict" ? qsTr("Plik zmienił się przed zapisem. Wczytaj zmiany i spróbuj ponownie.")
                : reason === "verify" ? qsTr("Nie potwierdzono zapisu. Plik zmienił się lub jest niedostępny. Sprawdź go przed ponowną próbą.")
                : qsTr("Nie zapisano ustawień. Sprawdź dostęp do pliku i możliwość utworzenia katalogu putkin.");
            if (reason === "verify") root.conflict = true;
        }
    }
    Component.onCompleted: observe()
}
