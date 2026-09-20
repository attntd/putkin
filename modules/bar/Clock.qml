import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../core"

Controls.Control {
    id: root
    required property date date
    property int dateStyle: 2
    property bool windowedTooltip: false
    readonly property string timeText: date.toLocaleTimeString(locale, locale.timeFormat(Locale.ShortFormat).replace(/([:.\s])s{1,2}/g, ""))
    readonly property string dateText: dateStyle === 0 ? "" : (dateStyle === 2 ? date.toLocaleDateString(locale, "ddd") + " " : "") + date.toLocaleDateString(locale, Locale.ShortFormat)
    readonly property string fullDate: date.toLocaleDateString(locale, Locale.LongFormat)
    readonly property string label: (dateText.length > 0 ? dateText + "  " : "") + timeText

    objectName: "clock"
    implicitWidth: labelText.implicitWidth + Metrics.space16
    implicitHeight: Metrics.barHeight
    padding: Metrics.space8
    verticalPadding: 0
    hoverEnabled: true
    Accessible.role: Accessible.StaticText
    Accessible.name: fullDate + " " + timeText
    FontMetrics { id: metrics; font: labelText.font }
    contentItem: Item {
        Text {
            id: labelText
            objectName: "clockLabel"
            readonly property rect inkBounds: metrics.tightBoundingRect(text)
            // Center the visible glyphs, not the font's ascent/descent line box.
            y: Math.round(((parent.height - inkBounds.height) / 2 - baselineOffset - inkBounds.y)
                * Screen.devicePixelRatio) / Screen.devicePixelRatio
            text: root.label
            textFormat: Text.PlainText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.fontSize
        }
    }
}
