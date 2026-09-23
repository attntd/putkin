/* Private namespace fixture only. Never install or use with host PAM. */
#define _DEFAULT_SOURCE
#include <security/pam_modules.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int converse(pam_handle_t *handle, int style, const char *text, char **value) {
    const void *item = NULL;
    if (pam_get_item(handle, PAM_CONV, &item) != PAM_SUCCESS || !item) return PAM_SYSTEM_ERR;
    const struct pam_conv *conversation = item;
    const struct pam_message message = {style, text};
    const struct pam_message *messages[] = {&message};
    struct pam_response *response = NULL;
    int code = conversation->conv(1, messages, &response, conversation->appdata_ptr);
    if (response) {
        if (value && response[0].resp) *value = strdup(response[0].resp);
        free(response[0].resp); free(response);
    }
    return code;
}

int pam_sm_authenticate(pam_handle_t *handle, int flags, int argc, const char **argv) {
    (void)flags; (void)argc; (void)argv;
    char name[32] = {0};
    FILE *comm = fopen("/proc/1/comm", "r");
    if (!comm) return PAM_SYSTEM_ERR;
    if (!fgets(name, sizeof(name), comm)) { fclose(comm); return PAM_SYSTEM_ERR; }
    fclose(comm);
    const char *base = getenv("PUTKIN_WAYLAND_TEST_DIR");
    if (strcmp(name, "bwrap\n") || !base || strncmp(base, "/tmp/", 5)) return PAM_SYSTEM_ERR;
    char *response = NULL;
    if (converse(handle, PAM_PROMPT_ECHO_OFF, "Fixture password", &response) != PAM_SUCCESS) return PAM_CONV_ERR;
    int code = response && !strcmp(response, "hjkl") ? PAM_SUCCESS : PAM_AUTH_ERR;
    if (response) { memset(response, 0, strlen(response)); free(response); }
    return code;
}

int pam_sm_setcred(pam_handle_t *handle, int flags, int argc, const char **argv) {
    (void)handle; (void)flags; (void)argc; (void)argv;
    return PAM_SUCCESS;
}
