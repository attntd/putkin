import QtQuick
import "AuthenticationMessages.js" as Messages

AuthenticationRequest {
    id: root
    required property var flow
    property bool scanning: false
    property bool submitted: false
    property bool initialized: false
    property int fingerprintTimeoutMs: 0
    fingerprintCountdown: scanning && fingerprintTimeoutMs > 0
    responseRequired: flow !== null && flow.isResponseRequired
    responseVisible: flow !== null && flow.responseVisible

    function updatePrompt(): void {
        if (!flow || !flow.isResponseRequired) return;
        if (scanning || fingerprintProgress > 0) fingerprintProgress = 1;
        scanning = false;
        countdown.stop();
        // A one-attempt PAM policy can request the password in the same event
        // batch as the mismatch. Keep its red glyph long enough to render.
        if (fingerprintState !== "error") fingerprintState = "hidden";
        prompt = /password|hasło/i.test(flow.inputPrompt) ? qsTr("Hasło") : flow.inputPrompt;
    }
    function updateMessage(): void {
        if (!flow) return;
        const kind = Messages.fingerprint(flow.supplementaryMessage);
        if (kind === "ready") {
            if (!scanning) {
                fingerprintProgress = 0;
                if (fingerprintTimeoutMs > 0) countdown.restart();
            }
            scanning = true;
            submitted = false;
            errorText = "";
            if (fingerprintState !== "error") fingerprintState = "idle";
        } else if (kind === "mismatch" || kind === "retry") {
            scanning = true;
            fingerprintState = "error";
            errorText = "";
            reset.restart();
        } else if (kind === "timeout") {
            scanning = false;
            countdown.stop();
            fingerprintProgress = 1;
            fingerprintState = "hidden";
        } else if (flow.supplementaryIsError) {
            errorText = scanning ? qsTr("Błąd czytnika odcisków palców: ") + flow.supplementaryMessage : flow.supplementaryMessage;
            if (scanning) fingerprintState = "error";
        }
    }
    // Native flow owns the PAM conversation and the authorization cookie.
    function submit(response: string): void {
        if (done || !flow || !flow.isResponseRequired) return;
        submitted = true;
        fingerprintState = "hidden";
        invalid = false;
        errorText = "";
        flow.submit(response);
    }
    function cancel(): void {
        if (done) return;
        if (flow) flow.cancelAuthenticationRequest();
        finish();
    }
    onIdentitySelected: index => {
        if (!flow) return;
        countdown.stop(); fingerprintProgress = 0;
        scanning = false; submitted = false; fingerprintState = "hidden";
        errorText = ""; invalid = false;
        flow.selectedIdentity = flow.identities[index];
    }
    readonly property Connections events: Connections {
        target: root.flow
        function onInputPromptChanged(): void { root.updatePrompt(); }
        function onIsResponseRequiredChanged(): void { root.updatePrompt(); }
        function onSupplementaryMessageChanged(): void { root.updateMessage(); }
        function onAuthenticationSucceeded(): void {
            if (root.scanning && !root.submitted) root.fingerprintState = "success";
            root.finish();
        }
        function onAuthenticationFailed(): void {
            if (root.submitted) { root.invalid = true; root.errorText = qsTr("Uwierzytelnienie nie powiodło się"); }
        }
        function onIsCancelledChanged(): void { if (root.flow && root.flow.isCancelled) root.finish(); }
    }
    readonly property Timer reset: Timer {
        interval: 2000
        onTriggered: { if (!root.done && root.fingerprintState === "error" && !root.errorText) root.fingerprintState = root.scanning ? "idle" : "hidden"; }
    }
    readonly property NumberAnimation countdown: NumberAnimation {
        target: root
        property: "fingerprintProgress"
        from: 0; to: 1
        duration: root.fingerprintTimeoutMs
        easing.type: Easing.Linear
    }
    onDoneChanged: { if (done) countdown.stop(); }
    onFlowChanged: { if (initialized && !flow) finish(); }
    Component.onCompleted: {
        context = flow.message;
        identities = Array.from(flow.identities).map(identity => identity.displayName || identity.string);
        identityIndex = Array.from(flow.identities).indexOf(flow.selectedIdentity);
        updatePrompt(); updateMessage();
        initialized = true;
    }
}
