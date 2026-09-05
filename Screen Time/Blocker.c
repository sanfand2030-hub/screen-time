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

static bool is_blocking_active = false;
static char **allowed_paths = NULL;
static size_t allowed_paths_ct = 0;

static bool is_allowed_path(const char *executable_path)
{
    // Guard against NULL state safely
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
    if (strstr(path, "Applications/") || strstr(path, "/Users/")) {
        if (strstr(path, ".app/Contents/MacOS/"))
            return true;
    }
    return false;
}

// TODO: fix
void check_running_processes(void)
{
    if (!is_blocking_active || allowed_paths == NULL || allowed_paths_ct == 0) {
        printf("debug: blocking is not active or allowed_paths is empty.\n");
        assert(0);
    }

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

void start_blocking_session(int duration_seconds, const char **allowed, int count) {
    if (count <= 0 || allowed == NULL) return;

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
