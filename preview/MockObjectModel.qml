import QtQml.Models

ListModel {
    id: root
    property var values: []
    function reset(objects: var): void {
        clear();
        for (const object of objects) append({ modelData: object });
        values = objects.slice();
    }
    function removeObject(object: var): void {
        const index = values.indexOf(object);
        if (index < 0) return;
        remove(index);
        values = values.filter(value => value !== object);
    }
}
