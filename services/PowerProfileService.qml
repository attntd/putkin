import QtQml

// Profile names and selection adapted from putpuccin/PowerService.
QtObject {
    id: root
    required property var backend
    readonly property bool available: backend.available
    readonly property string profile: available ? backend.profile : ""
    readonly property bool busy: backend.busy
    readonly property string pendingProfile: backend.pendingProfile
    readonly property string lastError: backend.lastError
    readonly property var choices: [
        {id: "power-saver", title: qsTr("Oszczędny"), glyph: "eco"},
        {id: "balanced", title: qsTr("Zrównoważony"), glyph: "balance"},
        {id: "performance", title: qsTr("Wydajność"), glyph: "bolt"}
    ]
    readonly property string availabilityText: !available ? qsTr("Tryby pracy niedostępne")
        : !supports("performance") ? qsTr("Tryb wydajności niedostępny na tym urządzeniu") : ""
    readonly property string limitationText: !available || profile !== "performance" ? ""
        : backend.degradationReason === "lap-detected" ? qsTr("Wydajność ograniczona — komputer na kolanach")
        : backend.degradationReason === "high-operating-temperature" ? qsTr("Wydajność ograniczona — wysoka temperatura")
        : backend.degradationReason ? qsTr("Wydajność czasowo ograniczona") : ""

    function supports(value: string): bool { return available && backend.profiles.indexOf(value) >= 0; }
    function setProfile(value: string): void {
        if (!busy && supports(value) && value !== profile) backend.setProfile(value);
    }
    function refresh(): void { backend.refresh(); }
}
