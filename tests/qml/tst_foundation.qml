import QtQuick
import QtTest
import "../../preview"

Item {
    id: scene
    width: 720
    height: 440

    MockState { id: mock }
    FoundationView {
        id: view
        anchors.fill: parent
        model: mock
    }

    TestCase {
        id: tests
        name: "Foundation"
        when: windowShown

        property var actionButton
        property var resetButton
        property var slider

        SignalSpy {
            id: disabledClicks
            target: tests.findChild(view, "disabledButton")
            signalName: "clicked"
        }

        function initTestCase() {
            actionButton = findChild(view, "actionButton");
            resetButton = findChild(view, "resetButton");
            slider = findChild(view, "levelSlider");
            verify(actionButton !== null && resetButton !== null && slider !== null);
        }

        function init() {
            failOnWarning(/.*/);
            mock.reset();
            view.focusFirst();
            mouseMove(scene, 1, 1);
            disabledClicks.clear();
        }

        function test_button_keyboard_mouse_and_disabled() {
            verify(actionButton.activeFocus);
            keyClick(Qt.Key_Space);
            compare(mock.selected, true);
            compare(actionButton.text, "Wybrano");
            keyClick(Qt.Key_Space);
            compare(mock.selected, false);
            mouseClick(actionButton);
            compare(mock.selected, true);
            mouseClick(findChild(view, "disabledButton"));
            compare(disabledClicks.count, 0);
        }

        function test_tab_skips_disabled_and_focus_is_visible() {
            verify(findChild(actionButton, "focusIndicator").visible);
            keyClick(Qt.Key_Tab);
            verify(resetButton.activeFocus);
            verify(findChild(resetButton, "focusIndicator").visible);
            verify(!findChild(actionButton, "focusIndicator").visible);
            keyClick(Qt.Key_Tab);
            verify(slider.activeFocus);
            verify(findChild(slider, "focusIndicator").visible);
            keyClick(Qt.Key_Backtab);
            verify(resetButton.activeFocus);
        }

        function test_slider_keyboard_bounds_and_reset_binding() {
            slider.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Right);
            compare(mock.level, 65);
            keyClick(Qt.Key_Left);
            compare(mock.level, 60);
            for (let i = 0; i < 30; ++i)
                keyClick(Qt.Key_Right);
            compare(mock.level, 100);
            for (let i = 0; i < 30; ++i)
                keyClick(Qt.Key_Left);
            compare(mock.level, 0);
            resetButton.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            compare(mock.level, 60);
            compare(slider.value, 60);
            compare(findChild(view, "levelLabel").text, "60%");
        }

        function test_slider_mouse_updates_model() {
            mouseClick(slider, slider.width * 0.8, slider.height / 2);
            verify(mock.level >= 75 && mock.level <= 85);
            compare(slider.value, mock.level);
        }

        function test_tooltip_and_accessible_name() {
            compare(resetButton.Accessible.name, "Przywróć próbkę");
            compare(slider.Accessible.name, "Poziom próbki");
            mouseMove(resetButton, resetButton.width / 2, resetButton.height / 2);
            wait(650);
            compare(findChild(resetButton, "tooltip"), null);
            verify(resetButton.hovered);

        }
    }
}
