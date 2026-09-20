import QtQuick
import "../core"

Item {
    id: root
    property string text: ""
    property string leadingIcon: ""
    property string trailingIcon: ""
    property string section: "list"
    property color color: Theme.text
    property font font: Qt.font({family: Theme.fontFamily, pixelSize: Metrics.fontSize})
    property int horizontalAlignment: Text.AlignHCenter
    readonly property int textFormat: Text.PlainText
    implicitWidth: label.implicitWidth + leading.width + trailing.width
        + (leadingIcon ? Metrics.space4 : 0) + (trailingIcon ? Metrics.space4 : 0)
    implicitHeight: Math.max(label.implicitHeight, leadingIcon || trailingIcon ? leading.slotSize : 0)
    Glyph {
        id: leading
        section: root.section
        width: root.leadingIcon ? slotSize : 0
        height: slotSize
        anchors.verticalCenter: parent.verticalCenter
        symbol: root.leadingIcon
        color: root.color
    }
    Text {
        id: label
        anchors.left: leading.right
        anchors.leftMargin: root.leadingIcon ? Metrics.space4 : 0
        anchors.right: trailing.left
        anchors.rightMargin: root.trailingIcon ? Metrics.space4 : 0
        height: parent.height
        text: root.text
        textFormat: Text.PlainText
        font: root.font
        color: root.color
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    Glyph {
        id: trailing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        section: root.section
        width: root.trailingIcon ? slotSize : 0
        height: slotSize
        symbol: root.trailingIcon
        color: root.color
    }
}
