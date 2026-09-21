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
    MockMessagingBackend { id: backend; groupsEnabled: true }
    SignalService { id: service; backend: backend }
    SignalMessagingAdapter { id: adapter; service: service }
    MessageHub { id: hub; adapters: [adapter] }
    MockSettingsFile { id: file }
    Settings { id: settings; storage: file }
    Binding { target: Theme; property: "appearance"; value: settings.effective }
    Loader { id: view; anchors.fill: parent; active: false; sourceComponent: MessagesView { hub: hub; readingEnabled: true } }
    TestCase {
        name: "SignalGroups"
        when: windowShown
        function control(name) { return findChild(view.item, name); }
        function choose() {
            hub.openConversation(adapter.address("chat-g"));
            tryVerify(() => adapter.draftReady && !adapter.loading); wait(60);
        }
        function details() {
            control("conversationDetails").click();
            tryVerify(() => control("groupName") !== null && adapter.directoryBusy === 0);
        }
        function initTestCase() { wait(100); }
        function init() {
            failOnWarning(/.*/);
            scene.width = 980; scene.height = 720;
            view.active = false; backend.seed();
            backend.directory = {ownServiceId: "aci:self", contacts: [
                {serviceId: "aci:peer", name: "Alicja", number: "+12025550101", username: "alice.42", about: "Projekt"},
                {serviceId: "aci:other", name: "Łukasz", number: "+12025550102"}],
                groups: [{groupId: "group", name: "Projekt", description: "Opis", ownServiceId: "aci:self", membership: "member", isMember: true,
                    canSend: true, canAdmin: true, canEdit: true, canAdd: true, canAccept: false, canLeave: true,
                    members: [{serviceId: "aci:self", isAdmin: true}, {serviceId: "aci:peer", isAdmin: false}], pendingMembers: [], requestingMembers: [],
                    permissionAddMember: "ONLY_ADMINS", permissionEditDetails: "ONLY_ADMINS", permissionSendMessage: "EVERY_MEMBER", inviteLink: ""}]};
            backend.rows.forEach(r => { r.canRead = true; r.requestState = r.kind === "group" ? "member" : "accepted"; });
            adapter.clear(); view.active = true;
            tryCompare(view, "status", Loader.Ready); tryCompare(adapter, "listLoading", false);
        }
        function cleanup() { backend.release(); settings.cancelEdit(); view.active = false; wait(100); }
        function test_group_creation_selects_members_once_and_opens_result() {
            control("newConversation").click(); control("newGroupMode").click();
            const name = control("newGroupName"); name.forceActiveFocus(Qt.TabFocusReason);
            for (const c of "hjkl") keyClick(c);
            compare(name.text, "hjkl");
            const list = control("contactList"); list.currentIndex = 0; list.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            verify(control("createGroup").enabled);
            control("createGroup").click();
            tryVerify(() => adapter.selectedRoute !== null && adapter.selectedRoute.conversationId === "chat-g");
            const calls = backend.calls.filter(c => c.method === "group.create");
            compare(calls.length, 1); compare(calls[0].params.members, ["aci:peer"]); compare(calls[0].params.name, "hjkl");
        }
        function test_unknown_create_stays_blocked_and_offers_readback() {
            backend.groupResult = "unknown";
            control("newConversation").click(); control("newGroupMode").click();
            control("newGroupName").text = "Niepewna";
            const list = control("contactList"); list.currentIndex = 0; list.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_Return);
            control("createGroup").click(); tryVerify(() => adapter.createUncertain);
            verify(!control("createGroup").enabled);
            control("reconcileGroup").click();
            tryVerify(() => backend.calls.some(c => c.method === "group.reconcile"));
            compare(backend.calls.filter(c => c.method === "group.create").length, 1);
        }
        function test_destructive_action_targets_member_and_defaults_cancel() {
            choose(); details();
            const remove = control("removeMember");
            // First delegate is self and its controls are hidden; use visible peer.
            const detail = findChild(view.item, "closeConversationDetails").parent.parent.parent;
            function findVisible(item, name) {
                if (item.objectName === name && item.visible) return item;
                for (const child of item.children || []) { const found = findVisible(child, name); if (found) return found; }
                return null;
            }
            const button = findVisible(detail, "removeMember"); verify(button !== null); button.click();
            tryVerify(() => control("cancelGroupAction").activeFocus);
            verify(!backend.calls.some(c => c.method === "group.update"));
            control("confirmGroupAction").click();
            tryVerify(() => backend.calls.some(c => c.method === "group.update"));
            const call = backend.calls.find(c => c.method === "group.update");
            compare(call.params.members, ["aci:peer"]); compare(call.params.confirm, "group");
        }
        function test_lost_membership_disables_composer_and_admin_controls() {
            choose(); details();
            adapter.groupAction("quit", {confirm: "group"});
            tryVerify(() => !adapter.canSend && adapter.groupDetails.membership === "left");
            verify(!control("saveGroupDetails").visible);
            control("closeConversationDetails").click();
            verify(!control("messageEditor").enabled);
        }
        function test_request_accept_mute_hide_and_block_are_distinct() {
            backend.rows[0].canRead = false; backend.rows[0].canSend = false; backend.rows[0].requestState = "pending";
            adapter.refresh(); hub.openConversation(adapter.address("chat-a"));
            tryVerify(() => adapter.draftReady && !adapter.loading);
            verify(control("acceptMessageRequest").visible); verify(!adapter.canSend);
            control("acceptMessageRequest").click(); tryVerify(() => adapter.canSend);
            details(); control("muteConversation").click();
            tryVerify(() => backend.calls.some(c => c.method === "conversation.notifications"));
            control("hideConversation").click(); tryVerify(() => adapter.selectedConversation.hidden);
            control("blockConversation").click(); control("confirmGroupAction").click(); tryVerify(() => !adapter.canSend);
            verify(backend.calls.some(c => c.method === "conversation.block"));
        }
        function test_profiles_refresh_keep_selection_and_both_accents() {
            control("newConversation").click();
            const list = control("contactList"); list.currentIndex = 1; list.forceActiveFocus(Qt.TabFocusReason); keyClick(Qt.Key_K); keyClick(Qt.Key_J);
            control("refreshContacts").click(); tryCompare(adapter, "directoryBusy", 0); compare(list.currentIndex, 1);
            control("contactProfile").click(); tryVerify(() => adapter.profileDetails !== null);
            choose(); details();
            // Details no longer has an accent window frame; keyboard focus
            // remains an accent surface and must follow appearance previews.
            control("groupName").forceActiveFocus(Qt.TabFocusReason);
            waitForRendering(view.item); const before = grabImage(view.item);
            settings.beginEdit(); settings.setColor("accent", "#89b4fa"); settings.setColor("accentSecondary", "#f38ba8");
            waitForRendering(view.item); verify(!before.equals(grabImage(view.item))); settings.cancelEdit();
            scene.width = 360; scene.height = 480; wait(80);
            verify(control("closeConversationDetails").visible);
            verify(control("groupName").width <= 336);
        }
    }
}
