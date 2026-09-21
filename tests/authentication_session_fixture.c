/* Only replaces session discovery inside the isolated Polkit test. */
#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/types.h>
#include <errno.h>

int sd_pid_get_session(pid_t pid, char **session) {
    (void)pid;
    char name[32] = {0};
    FILE *file = fopen("/proc/1/comm", "r");
    if (!file) return -ENODATA;
    if (!fgets(name, sizeof(name), file)) name[0] = 0;
    fclose(file);
    if (strcmp(name, "bwrap\n") || !getenv("PUTKIN_AUTHENTICATION_TEST")) return -ENODATA;
    *session = strdup("putkin-auth-fixture");
    return *session ? 0 : -ENOMEM;
}
