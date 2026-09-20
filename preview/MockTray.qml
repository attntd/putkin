import QtQml

QtObject {
    id: root
    readonly property MockObjectModel items: MockObjectModel {}
    readonly property MockMenuEntry menu: MockMenuEntry { hasChildren: true }
    readonly property MockMenuEntry openEntry: MockMenuEntry { text: "Otwórz" }
    readonly property MockMenuEntry disabledEntry: MockMenuEntry { text: "Niedostępne"; enabled: false }
    readonly property MockMenuEntry separator: MockMenuEntry { isSeparator: true }
    readonly property MockMenuEntry sub: MockMenuEntry { text: "Opcje"; hasChildren: true }
    readonly property MockMenuEntry checkEntry: MockMenuEntry { text: "Synchronizacja"; buttonType: 1; checkState: Qt.Checked }
    readonly property MockMenuEntry leaf: MockMenuEntry { text: "Pokaż szczegóły" }
    readonly property Component factory: Component { MockTrayItem {} }
    readonly property Component menuComponent: Component {
        QtObject {
            property var handle: null
            readonly property var entries: handle ? handle.entries : null
        }
    }
    function reset(count: int): void {
        const previous = items.values;
        const values = [];
        for (let i = 0; i < count; ++i)
            values.push(factory.createObject(root, { objectName: "app" + i,
                title: ["Poczta", "Synchronizacja", "Muzyka"][i % 3] + " " + (i + 1),
                icon: i === 0 ? "" : Qt.resolvedUrl("../assets/icons/" + (i % 2 ? "brightness.svg" : "volume.svg")),
                menu: i === 2 ? null : menu, onlyMenu: i === 1 }));
        items.reset(values);
        for (const item of previous) item.destroy();
        openEntry.activations = 0; leaf.activations = 0; checkEntry.activations = 0;
        menu.entries.reset([openEntry, disabledEntry, separator, sub, checkEntry]);
        sub.entries.reset([leaf]);
    }
    Component.onCompleted: reset(16)
}
