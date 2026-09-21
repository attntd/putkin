pragma Singleton

import QtQuick

QtObject {
    function textFocused(scope: Item): bool {
        const window = scope.Window.window;
        for (let item = window ? window.activeFocusItem : null; item; item = item.parent)
            if (item instanceof TextInput || item instanceof TextEdit) return true;
        return false;
    }

    function matches(event: var, scope: Item): bool {
        return event.key === Qt.Key_Escape || (event.key === Qt.Key_Q
            && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.KeypadModifier)
            && !textFocused(scope));
    }
}
