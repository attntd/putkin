import QtQml

QtObject {
    id: root
    required property var service
    required property var screenNames
    property string screenName: ""

    signal entered(string name)
    signal resumed(string name, var invoker)

    function resume(name: string, invoker: var): void {
        if (screenNames.indexOf(name) < 0)
            return;
        screenName = name;
        resumed(name, invoker);
    }

    function focusBar(): string {
        const candidates = screenNames.filter(name => service.monitorAvailable(name));
        const name = candidates.indexOf(service.focusedMonitorName) >= 0
            ? service.focusedMonitorName : candidates.length > 0 ? candidates[0] : "";
        screenName = name;
        if (name.length > 0)
            entered(name);
        return name;
    }

    function close(): void {
        screenName = "";
    }

    function validate(): void {
        if (screenNames.indexOf(screenName) < 0 || !service.monitorAvailable(screenName))
            close();
    }

    onScreenNamesChanged: validate()
    readonly property Connections serviceChanges: Connections {
        target: root.service
        function onUpdated(): void { root.validate(); }
    }
}
