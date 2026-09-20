pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models

// Composition only: domain services never import UI or invoke notification commands.
QtObject {
    id: root
    required property var notifications
    property var sources: []
    readonly property Instantiator watchers: Instantiator {
        model: root.sources
        delegate: QtObject {
            required property var modelData
            readonly property string message: modelData.source ? String(modelData.source[modelData.property] || "") : ""
            onMessageChanged: { if (message) root.notifications.notifyError(modelData.title, message); }
        }
    }
}
