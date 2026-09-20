import QtQml

QtObject {
    id: root
    property bool available: true
    property string profile: "balanced"
    property var profiles: ["power-saver", "balanced", "performance"]
    property string degradationReason: ""
    property string pendingProfile: ""
    readonly property bool busy: pendingProfile !== ""
    property string lastError: ""
    property bool autoComplete: true
    property int calls: 0
    function refresh(): void {}
    function setProfile(value: string): void {
        calls++;
        pendingProfile = value;
        lastError = "";
        if (autoComplete) complete(true);
    }
    function complete(success: bool): void {
        if (success) profile = pendingProfile;
        else lastError = "Odmowa zmiany trybu pracy";
        pendingProfile = "";
    }
}
