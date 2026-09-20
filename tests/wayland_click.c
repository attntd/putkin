// One left click at the private compositor's current cursor position.
// Protocol v2 definition is vendored with its MIT license in protocols/.
#include <linux/input-event-codes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "virtual-pointer.h"

static struct zwlr_virtual_pointer_manager_v1 *manager;

static void global(void *data, struct wl_registry *registry, uint32_t id,
                   const char *interface, uint32_t version) {
    (void)data;
    if (strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name) == 0 && version >= 1)
        manager = wl_registry_bind(registry, id, &zwlr_virtual_pointer_manager_v1_interface, 1);
}

static void removed(void *data, struct wl_registry *registry, uint32_t id) {
    (void)data; (void)registry; (void)id;
}

static uint32_t timestamp(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (uint32_t)(now.tv_sec * 1000 + now.tv_nsec / 1000000);
}

int main(int argc, char **argv) {
    if (argc != 1 && argc != 3) return 2;
    const char *base = getenv("PUTKIN_WAYLAND_TEST_DIR");
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    const char *name = getenv("WAYLAND_DISPLAY");
    char expected[4096];
    if (!base || !runtime || !name || getenv("WAYLAND_SOCKET")) return 2;
    snprintf(expected, sizeof(expected), "%s/r", base);
    if (strcmp(runtime, expected) || strncmp(name, "wayland-", 8) || strchr(name, '/')) return 2;
    alarm(3);
    struct wl_display *display = wl_display_connect(name);
    if (!display) return 3;
    struct wl_registry *registry = wl_display_get_registry(display);
    const struct wl_registry_listener listener = {.global = global, .global_remove = removed};
    wl_registry_add_listener(registry, &listener, NULL);
    if (wl_display_roundtrip(display) < 0 || !manager) return 4;
    struct zwlr_virtual_pointer_v1 *pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    if (wl_display_roundtrip(display) < 0) return 5;
    zwlr_virtual_pointer_v1_button(pointer, timestamp(), BTN_LEFT, WL_POINTER_BUTTON_STATE_PRESSED);
    zwlr_virtual_pointer_v1_frame(pointer);
    if (wl_display_roundtrip(display) < 0) return 6;
    const struct timespec delay = {.tv_nsec = 30000000};
    nanosleep(&delay, NULL);
    if (argc == 3) {
        // Optional private drag, relative to the initial cursor position.
        int dx = atoi(argv[1]), dy = atoi(argv[2]);
        for (int step = 0; step < 10; ++step) {
            zwlr_virtual_pointer_v1_motion(pointer, timestamp(), wl_fixed_from_double(dx / 10.0), wl_fixed_from_double(dy / 10.0));
            zwlr_virtual_pointer_v1_frame(pointer);
            if (wl_display_roundtrip(display) < 0) return 6;
            nanosleep(&delay, NULL);
        }
    }
    zwlr_virtual_pointer_v1_button(pointer, timestamp(), BTN_LEFT, WL_POINTER_BUTTON_STATE_RELEASED);
    zwlr_virtual_pointer_v1_frame(pointer);
    if (wl_display_roundtrip(display) < 0) return 7;
    zwlr_virtual_pointer_v1_destroy(pointer);
    zwlr_virtual_pointer_manager_v1_destroy(manager);
    wl_registry_destroy(registry);
    wl_display_flush(display);
    wl_display_disconnect(display);
    return 0;
}
