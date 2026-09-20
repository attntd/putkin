.pragma library

// Quickshell 0.3.1 enums, verified against installed qmltypes and enums.hpp.
// Shared with Qt-only fixtures; production objects remain native QObjects.
var wifi = 1;
var wired = 2;
var connecting = 1;
var connected = 2;
var disconnecting = 3;
var disconnected = 4;
var noSecrets = 1;
var open = 10;
var unknownSecurity = 11;
function supportsPsk(security) { return security === 1 || security === 3 || security === 5; }
function securityName(security) {
    return ["WPA3 Enterprise", "WPA3 Personal", "WPA2 Enterprise", "WPA2 Personal",
        "WPA Enterprise", "WPA Personal", "WEP", "Dynamic WEP", "LEAP", "OWE", "Otwarta", "Nieznane"][security] || "Nieznane";
}
