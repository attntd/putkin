import QtQuick

QtObject {
    id: root
    property var applications: [
        {id: "kitty", name: "Kitty", genericName: "Terminal", comment: "", keywords: [], noDisplay: false},
        {id: "org.kde.dolphin", name: "Dolphin", genericName: "Menedżer plików", comment: "", keywords: ["files"], noDisplay: false},
        {id: "zen", name: "Zen Browser", genericName: "Przeglądarka", comment: "", keywords: ["internet"], noDisplay: false}
    ]
    property var clipboard: [{id: "7", preview: "Spotkanie jutro o 10:00", binary: false}, {id: "6", preview: "https://quickshell.org", binary: false}]
    property var history: [{kind: "application", id: "kitty"}, {kind: "file", id: "/home/demo/Dokumenty/Plan.md"}, {kind: "application", id: "zen"}]
    property string clipboardError: ""
    property string historyError: ""
    property string lastError: ""
    property bool ready: true
    property bool visible: false
    property var searches: []
    property var activations: []
    property var previews: []
    property bool automatic: true
    signal searched(int revision, var entries, string error)
    signal activated(int request, string error)
    signal previewed(int revision, string key, string text, string image, string error)
    function preview(revision: int, key: string): bool {
        previews = previews.concat([{revision: revision, key: key}]);
        const entry = clipboard.find(item => item.id === key);
        if (automatic && entry) Qt.callLater(() => root.previewed(revision, key,
            entry.fullText || (entry.binary ? "" : entry.preview), entry.image || "", ""));
        return true;
    }
    function setVisible(value: bool): void { visible = value; }
    function search(revision: int, query: string): bool {
        searches = searches.concat([{revision: revision, query: query}]);
        if (automatic) Qt.callLater(() => root.searched(revision, query ? ["/home/demo/Dokumenty/" + query + ".md"] : [], ""));
        return true;
    }
    function activate(request: int, entry: var): bool {
        activations = activations.concat([{request: request, entry: entry}]);
        if (automatic) Qt.callLater(() => root.activated(request, ""));
        return true;
    }
    function reset(): void {
        clipboardError = ""; historyError = ""; lastError = ""; ready = true;
        automatic = true; activations = []; searches = []; previews = [];
    }
}
