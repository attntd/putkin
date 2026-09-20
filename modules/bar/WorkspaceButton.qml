import QtQuick
import "../../components" as UI
import "../../core"

UI.Button {
    id: root
    required property int workspaceId
    required property bool occupied
    required property bool urgent
    required property string visibleOn
    required property string screenName
    readonly property bool activeHere: visibleOn.length > 0 && visibleOn === screenName
    readonly property bool activeElsewhere: visibleOn.length > 0 && visibleOn !== screenName

    implicitWidth: Metrics.workspaceWidth
    implicitHeight: Metrics.barHeight
    padding: Metrics.space4
    text: String(workspaceId)
    tooltip: qsTr("Workspace %1").arg(workspaceId)
        + (activeHere ? qsTr(" — aktywny tutaj") : activeElsewhere ? qsTr(" — widoczny na %1").arg(visibleOn) : "")
        + (occupied ? qsTr(", zajęty") : qsTr(", pusty")) + (urgent ? qsTr(", pilny") : "")
    Accessible.name: tooltip
    foreground: !enabled ? Theme.textDisabled : activeHere ? accentTextColor : urgent ? Theme.error : occupied ? accentColor : Theme.text
    font.weight: activeHere || urgent ? Font.Bold : occupied ? Font.DemiBold : Font.Normal
    background: UI.AccentRectangle {
        anchors.fill: parent
        anchors.margins: Metrics.space4
        color: root.activeHere ? Theme.accent : root.down ? Theme.surfaceHover : root.hovered ? Theme.surface : Theme.background
        border.width: root.activeHere ? Metrics.borderWidth : 0
        border.color: Theme.accentBorder
        accentFill: root.activeHere
        accentOutline: root.activeHere
        UI.FocusIndicator {
            control: root
            anchors.margins: Metrics.focusWidth
            border.color: root.activeHere ? root.accentTextColor : Theme.focus
        }
    }
}
