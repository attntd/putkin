pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../../core"
import "../../services"
import "../../preview"
import "../../modules/messages"

Item {
    id: scene
    width: 980; height: 720
    property bool eligible: false
    MockMessagingBackend { id: backend }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: messageHub; adapters: [adapter] }
    Loader {
        id: view
        anchors.fill: parent
        active: false
        sourceComponent: MessagesView { hub: messageHub; readingEnabled: scene.eligible }
    }
    TestCase {
        name: "SignalReceipts"
        when: windowShown
        function initTestCase() { wait(150); }
        function history() { return findChild(view.item, "messageHistory"); }
        function calls() { return backend.calls.filter(v => v.method === "messages.read"); }
        function choose(cid = "chat-a") {
            verify(messageHub.openConversation(adapter.address(cid)));
            tryVerify(() => adapter.selectedRoute !== null && adapter.selectedRoute.conversationId === cid && !adapter.loading);
            wait(120);
        }
        function init() {
            failOnWarning(/.*/);
            scene.eligible = false; scene.width = 980; scene.height = 720;
            view.active = false;
            backend.seed(); adapter.clear(); view.active = true;
            tryCompare(view, "status", Loader.Ready);
            tryCompare(adapter, "listLoading", false);
        }
        function cleanup() { scene.eligible = false; backend.release(); wait(150); view.active = false; }
        function test_visible_range_once_and_unread_shared_with_hub() {
            choose();
            compare(calls().length, 0);
            const visible = history().visibleUnread(); verify(visible.length > 0); verify(visible.length < adapter.messages.count);
            scene.eligible = true;
            tryVerify(() => calls().length === 1);
            compare(calls()[0].params.messageIds.slice().sort(), visible.slice().sort());
            tryCompare(messageHub, "unreadCount", 181 - visible.length);
            wait(650); compare(calls().length, 1);
            scene.eligible = false; scene.eligible = true; wait(350); compare(calls().length, 1);
            history().followEnd = false;
            history().positionViewAtIndex(10, ListView.Beginning);
            tryVerify(() => calls().length === 2);
            const all = calls().reduce((ids, call) => ids.concat(call.params.messageIds), []);
            compare(new Set(all).size, all.length);
        }
        function test_gate_loss_during_debounce_hidden_detail_and_closed_view() {
            choose(); scene.eligible = true; wait(70); scene.eligible = false; wait(350);
            compare(calls().length, 0);
            scene.width = 320; (view.item as MessagesView).showList(); scene.eligible = true; wait(350);
            compare(calls().length, 0);
            (view.item as MessagesView).creating = true; wait(350); compare(calls().length, 0);
            view.active = false; backend.incoming("chat-a"); wait(350); compare(calls().length, 0);
        }
        function test_incoming_outside_scrolled_view_and_stale_route_do_not_read() {
            choose(); history().followEnd = false; history().positionViewAtIndex(10, ListView.Beginning);
            tryVerify(() => history().itemAtIndex(10) !== null && !history().restoring);
            wait(100); scene.eligible = true;
            tryVerify(() => calls().length === 1); wait(350);
            const count = calls().length;
            backend.incoming("chat-a"); wait(450);
            compare(calls().length, count);
            verify(backend.history["chat-a"][backend.history["chat-a"].length - 1].unread);
            adapter.markVisible(adapter.address("chat-g"), ["group-1"]);
            compare(calls().length, count);
        }
        function test_status_counts_accessible_and_unknown_not_delivered() {
            choose();
            const sample = Object.assign(backend.message("chat-a", "receipt-row", 1000), {
                direction: "outgoing", unread: false, status: "sent", receiptSummary: {total: 3, delivered: 2, read: 1, viewed: 0}});
            adapter.merge([sample], false);
            const row = adapter.messages.get(adapter.messages.count - 1);
            verify(row.status.includes("Wysłano")); verify(row.status.includes("Dostarczono 2/3")); verify(row.status.includes("Przeczytano 1/3"));
            history().positionViewAtEnd(); wait(150);
            const delegate = history().itemAtIndex(history().count - 1);
            verify(delegate.Accessible.name.includes("Przeczytano 1/3"));
            sample.status = "unknown"; sample.receiptSummary = {total: 1, delivered: 0, read: 0, viewed: 0};
            adapter.merge([sample], false);
            compare(adapter.messages.get(adapter.messages.count - 1).status, "Wynik nieznany");
        }
    }
}
