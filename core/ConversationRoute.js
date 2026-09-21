.pragma library

// Opaque IDs, including the account, cross every UI and notification boundary.
function valid(route) {
    return route && [route.serviceId, route.accountId, route.conversationId].every(
        value => typeof value === "string" && value.length > 0 && value.length <= 256);
}
function key(route) { return valid(route) ? JSON.stringify([route.serviceId, route.accountId, route.conversationId]) : ""; }
function equal(a, b) { return key(a) !== "" && key(a) === key(b); }
function copy(route) { return valid(route) ? {serviceId: route.serviceId, accountId: route.accountId, conversationId: route.conversationId} : null; }
