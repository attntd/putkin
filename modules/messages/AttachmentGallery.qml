pragma ComponentBehavior: Bound
import QtQuick
import "../../core"

Item {
    id: root
    required property var attachments
    property color textColor: Theme.text
    property color mutedTextColor: Theme.textMuted
    property bool playbackEnabled: false
    property var audioOwner: null
    readonly property bool visualOnly: attachments.length > 0 && attachments.every(a => /^(image|video)\//.test(a.content_type))
    readonly property bool tiled: visualOnly && attachments.length > 1 && attachments.every(a => a.state === "ready" && !a.errorCode)
    readonly property int count: attachments.length
    readonly property real gap: 2
    implicitHeight: cards.items.reduce((bottom, card) => Math.max(bottom, card.y + card.height), 0)
    signal previewRequested(var attachment, int reason)
    signal ensureVisible(Item item)
    function cell(index: int): rect {
        if (!tiled) {
            let top = 0;
            for (const previous of cards.items) if (previous.index < index) top += previous.height + Metrics.space4;
            const visual = /^(image|video)\//.test(attachments[index].content_type);
            return Qt.rect(visual ? 0 : Metrics.space12, top, width - (visual ? 0 : 2 * Metrics.space12), 0);
        }
        const half = (width - gap) / 2;
        if (count === 3) {
            const large = (width - gap) * 2 / 3;
            return index === 0 ? Qt.rect(0, 0, large, large)
                : Qt.rect(large + gap, (index - 1) * (large + gap) / 2, width - large - gap, (large - gap) / 2);
        }
        if (count <= 4 || index < 2) return Qt.rect((index % 2) * (half + gap), Math.floor(index / 2) * (half + gap), half, half);
        const third = (width - 2 * gap) / 3;
        return Qt.rect(((index - 2) % 3) * (third + gap), half + gap + Math.floor((index - 2) / 3) * (third + gap), third, third);
    }
    Repeater {
        id: cards
        property var items: []
        onItemAdded: (_index, item) => { items = items.concat([item]); }
        onItemRemoved: (_index, item) => { items = items.filter(value => value !== item); }
        model: root.attachments
        delegate: AttachmentCard {
            required property var modelData
            required property int index
            readonly property rect cell: root.cell(index)
            x: cell.x; y: cell.y; width: cell.width
            mediaHeight: cell.height
            attachment: modelData
            textColor: root.textColor
            mutedTextColor: root.mutedTextColor
            playbackEnabled: root.playbackEnabled
            audioOwner: root.audioOwner
            onEnsureVisible: item => root.ensureVisible(item)
            onPreviewRequested: (attachment, reason) => root.previewRequested(attachment, reason)
        }
    }
}
