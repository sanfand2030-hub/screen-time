#include "Blocker.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libproc.h>
#include <sys/proc_info.h>
#include <signal.h>
#include <CoreFoundation/CoreFoundation.h>
#include <assert.h>

#ifdef NDEBUG
#define printf(...) ((void)0)
#endif

static bool is_blocking_active = false;
static char **allowed_paths = NULL;
static size_t allowed_paths_ct = 0;

static bool is_allowed_path(const char *executable_path)
{
    if (allowed_paths == NULL || allowed_paths_ct == 0) return false;
    
    for (size_t i = 0; i < allowed_paths_ct; i++) {
        if (allowed_paths[i] != NULL) {
            if (strstr(executable_path, allowed_paths[i]) != NULL)
                return true;
        }
    }
    return false;
}

static bool is_user_app(const char *path)
{
    // Core target path validation
    if (!strstr(path, "Applications/") && !strstr(path, "/Users/")) {
        return false;
    }
    
    // Ensure it's inside app bundle
    const char *app_extension = strstr(path, ".app/Contents/MacOS/");
    if (!app_extension) {
        return false;
    }

    // Extract path to root .app directory
    size_t bundle_path_len = (size_t)(app_extension - path + 4); // Include ".app"
    char bundle_path[PROC_PIDPATHINFO_MAXSIZE];
    
    if (bundle_path_len >= sizeof(bundle_path)) return false;
    
    strncpy(bundle_path, path, bundle_path_len);
    bundle_path[bundle_path_len] = '\0';

    // Inspect the App Bundle to check for LSUIElement / LSBackgroundOnly
    // This is to prevent background apps (like Google Drive) from being killed
    bool is_gui_app = true;

    CFStringRef cf_path = CFStringCreateWithFileSystemRepresentation(kCFAllocatorDefault, bundle_path);
    if (cf_path) {
        CFURLRef bundle_url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, cf_path, kCFURLPOSIXPathStyle, true);
        if (bundle_url) {
            CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, bundle_url);
            if (bundle) {
                // Check if LSUIElement (Agent / No Dock icon) is set to true
                CFTypeRef ui_element = CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("LSUIElement"));
                if (ui_element && CFGetTypeID(ui_element) == CFBooleanGetTypeID()) {
                    if (CFBooleanGetValue((CFBooleanRef)ui_element)) {
                        is_gui_app = false; // GUI-less agent
                    }
                }

                // Check if LSBackgroundOnly is set to true
                CFTypeRef bg_only = CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("LSBackgroundOnly"));
                if (bg_only && CFGetTypeID(bg_only) == CFBooleanGetTypeID()) {
                    if (CFBooleanGetValue((CFBooleanRef)bg_only)) {
                        is_gui_app = false; // Background-only process
                    }
                }

                CFRelease(bundle);
            }
            CFRelease(bundle_url);
        }
        CFRelease(cf_path);
    }

    return is_gui_app;
}

void check_running_processes(void)
{
    assert(is_blocking_active);
    assert(allowed_paths);
    assert(allowed_paths_ct);

    // 1. Query necessary byte buffer size for ALL processes
    int bytes_needed = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (bytes_needed <= 0) {
        printf("debug: proc_listpids failed to get buffer size (return code: %d).\n", bytes_needed);
        return;
    }

    // 2. Allocate memory with safety padding for processes spawned mid-check
    int base_count = bytes_needed / (int)sizeof(pid_t);
    int extra_padding = 64; // Cushion for newly created processes
    int alloc_count = base_count + extra_padding;
    int buffer_size = alloc_count * (int)sizeof(pid_t);

    pid_t *pids = malloc((size_t)buffer_size);
    assert(pids);

    // 3. Populate process list
    int actual_bytes = proc_listpids(PROC_ALL_PIDS, 0, pids, buffer_size);
    if (actual_bytes <= 0) {
        free(pids);
        assert(0);
    }

    int actual_ct = actual_bytes / (int)sizeof(pid_t);
    printf("debug: actual_ct processes found: %d\n", actual_ct);

    char path_buffer[PROC_PIDPATHINFO_MAXSIZE];

    for (int i = 0; i < actual_ct; i++) {
        pid_t curr_pid = pids[i];
        if (curr_pid <= 0 || curr_pid == getpid()) continue;

        // Fetch executable path (returns 0 if process belongs to another user without permissions)
        size_t path_len = proc_pidpath(curr_pid, path_buffer, sizeof(path_buffer));
        if (path_len <= 0) continue;

        if (!is_user_app(path_buffer)) continue;

        bool is_allowed_app = is_allowed_path(path_buffer);
        printf("debug: path_buffer: %s\n", path_buffer);
        printf("debug: is_allowed_app: %s\n", is_allowed_app ? "true" : "false");

        if (!is_allowed_app) {
            printf("[C Engine] Killing unallowed process: PID %d: %s\n", curr_pid, path_buffer);
            kill(curr_pid, SIGKILL);
        }
    }

    free(pids);
}

int start_blocking_session(int duration_seconds, const char **allowed, int count) {
    if (count <= 0 || allowed == NULL) {
        return 1;
    }
    printf("debug: count = %d\n", count);

    // Clean up existing paths if starting a new session
    if (allowed_paths != NULL) {
        stop_blocking_session();
    }

    printf("[C Engine] Session started for %d seconds.\n", duration_seconds);
    for (int i = 0; i < count; i++) {
        printf("[C Engine] Allowed app path: %s\n", allowed[i]);
    }

    allowed_paths = malloc((size_t)count * sizeof(char*));
    assert(allowed_paths != NULL);

    for (int i = 0; i < count; i++) {
        if (allowed[i] != NULL) {
            allowed_paths[i] = strdup(allowed[i]);
        } else {
            allowed_paths[i] = NULL;
        }
    }

    allowed_paths_ct = (size_t)count;
    is_blocking_active = true;
    
    return 0;
}

void stop_blocking_session(void) {
    printf("[C Engine] Session stopped.\n");
    is_blocking_active = false;

    if (allowed_paths != NULL) {
        for (size_t i = 0; i < allowed_paths_ct; i++) {
            if (allowed_paths[i] != NULL) {
                free(allowed_paths[i]);
            }
        }
        free(allowed_paths);
        allowed_paths = NULL;
    }
    allowed_paths_ct = 0;
}

void check_and_enforce_rules(const char **allowed_paths_param, int32_t ct) {
    printf("Allowed count: %d\n", ct);
    check_running_processes();
}
