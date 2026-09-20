import QtQuick
import QtQuick.Layouts
import "../core"
import "../components" as UI

Rectangle {
    id: root

    required property MockState model

    implicitWidth: 720
    implicitHeight: 440
    color: Theme.background

    function focusFirst(): void {
        actionButton.forceActiveFocus(Qt.TabFocusReason);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.space24
        spacing: Metrics.space16

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "putkin"
                font.family: Theme.fontFamily
                font.pixelSize: 24
                font.bold: true
                color: Theme.text
            }
            Item { Layout.fillWidth: true }
            Text {
                text: qsTr("PODGLĄD / 00")
                font.family: Theme.fontFamily
                font.pixelSize: Metrics.smallFontSize
                color: Theme.accent
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Mocha. Dwa akcenty. Kwadratowe kontrolki.")
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.fontSize
            color: Theme.textMuted
            wrapMode: Text.Wrap
        }

        UI.PanelFrame {
            Layout.fillWidth: true
            contentItem: ColumnLayout {
                spacing: Metrics.space16
                Text {
                    text: qsTr("Kontrolki")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.fontSize
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Metrics.space4
                    spacing: Metrics.space16

                    UI.Button {
                        id: actionButton
                        objectName: "actionButton"
                        text: root.model.selected ? qsTr("Wybrano") : qsTr("Wybierz")
                        highlighted: true
                        checkable: true
                        checked: root.model.selected
                        tooltip: qsTr("Przełącz stan próbki")
                        onClicked: root.model.toggle()
                    }
                    UI.Button {
                        objectName: "disabledButton"
                        text: qsTr("Niedostępne")
                        enabled: false
                    }
                    Item { Layout.fillWidth: true }
                    UI.IconButton {
                        objectName: "resetButton"
                        accessibleName: qsTr("Przywróć próbkę")
                        symbol: "refresh"
                        onClicked: root.model.reset()
                    }
                }
            }
        }

        UI.PanelFrame {
            Layout.fillWidth: true
            contentItem: ColumnLayout {
                spacing: Metrics.space8
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Poziom próbki")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.fontSize
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        objectName: "levelLabel"
                        text: root.model.level + "%"
                        color: Theme.accentSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.fontSize
                    }
                }
                UI.Slider {
                    objectName: "levelSlider"
                    Layout.fillWidth: true
                    accessibleName: qsTr("Poziom próbki")
                    fillColor: Theme.accentSecondary
                    from: 0
                    to: 100
                    stepSize: 5
                    value: root.model.level
                    onMoved: root.model.setLevel(value)
                }
            }
        }

        Item { Layout.fillHeight: true }
        Text {
            Layout.fillWidth: true
            text: qsTr("Tab: fokus  ·  Spacja: wybór  ·  ← →: poziom")
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.smallFontSize
            color: Theme.textMuted
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Dane demonstracyjne — bez połączenia z usługami systemu.")
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.smallFontSize
            color: Theme.textMuted
            wrapMode: Text.Wrap
        }
    }
}
