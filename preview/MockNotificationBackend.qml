import QtQuick

QtObject {
    id: root
    property bool available: true
    property string errorText: ""
    property int nextId: 1
    property var objects: []
    property var closedEvents: []
    property var actionEvents: []
    signal notification(var value, real id)
    signal replacement(real id, var actions, int timeout)
    function find(id: int): var { return objects.find(value => value.notificationId === id) || null; }
    function send(options: var): int {
        const previous = options.replacesId ? find(options.replacesId) : null;
        const value = previous || template.createObject(root, {notificationId: nextId++});
        const properties = ["appName", "appIcon", "summary", "body", "image", "expireTimeout", "urgency", "resident", "hints"];
        properties.forEach(key => { if (options[key] !== undefined) value[key] = options[key]; });
        if (options.transient !== undefined) value.isTransient = options.transient;
        value.setActions(options.actions || []);
        if (!previous) {
            const id = value.notificationId;
            objects = objects.concat([value]);
            value.closed.connect(reason => {
                root.closedEvents = root.closedEvents.concat([{id: id, reason: reason}]);
                root.objects = root.objects.filter(object => object !== value);
                value.destroy();
            });
            value.invoked.connect(action => root.actionEvents = root.actionEvents.concat([{id: id, action: action}]));
            notification(value, id);
        } else replacement(value.notificationId, (options.actions || []).reduce((all, action) => all.concat(action), []), value.expireTimeout);
        return value.notificationId;
    }
    readonly property Component template: Component { MockNotification {} }
}
