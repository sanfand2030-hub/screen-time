//
//  Blocker.c
//  Screen Time
//
//  Created by BUQI DONG on 2/9/2026.
//

#include "Blocker.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libproc.h>
#include <sys/proc_info.h>
#include <CoreFoundation/CoreFoundation.h>

static bool is_blocking_active = false;
static char **allowed_paths = NULL;
static size_t allowed_paths_ct = 0;

static bool is_user_app(const char *path)
{
    if (strstr(path, "Applications/") || strstr(path, "/Users/")) {
        if (strstr(path, ".app/Contents/MacOS/"))
            return true;
    }
    return false;
}

static char* get_bundle_identifier(const char *executable_path) {
    CFStringRef pathStr = CFStringCreateWithCString(kCFAllocatorDefault, executable_path, kCFStringEncodingUTF8);
    if (!pathStr) return NULL;

    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, pathStr, kCFURLPOSIXPathStyle, true);
    CFRelease(pathStr);
    if (!url) return NULL;

    // Locate enclosing bundle from binary path
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
    CFRelease(url);
    if (!bundle) return NULL;

    CFStringRef bundleIdStr = CFBundleGetIdentifier(bundle);
    char *result = NULL;

    if (bundleIdStr) {
        CFIndex length = CFStringGetLength(bundleIdStr);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
        result = (char *)malloc(maxSize);
        if (result) {
            if (!CFStringGetCString(bundleIdStr, result, maxSize, kCFStringEncodingUTF8)) {
                free(result);
                result = NULL;
            }
        }
    }

    CFRelease(bundle);
    return result;
}

void check_running_processes(void)
{
    size_t pid_ct = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (pid_ct <= 0)
        return;
    
    pid_t *pids = malloc(pid_ct * sizeof(pid_t));
    if (pids == NULL)
        exit(1);
    
    int actual_ct = proc_listpids(PROC_ALL_PIDS, 0, pids, (int)pid_ct * sizeof(pid_t)) / sizeof(pid_t);
    char path_buffer[PROC_PIDPATHINFO_MAXSIZE];
    for (int i = 0; i < actual_ct; i++) {
        pid_t curr_pid = pids[i];
        if (curr_pid <= 0)
            continue;
        // TODO: implement process
        size_t path_len = proc_pidpath(curr_pid, path_buffer, sizeof(path_buffer));
        if (path_len <= 0)
            continue;
        if (!is_user_app(path_buffer))
            continue;
        
        bool is_allowed_app = false;
        // TODO: finish implement
    }
}

void start_blocking_session(int duration_seconds, const char **allowed, int count) {
    if (count <= 0 || allowed == NULL)
        return;
    printf("[C Engine] Session started for %d seconds.\n", duration_seconds);
    for (int i = 0; i < count; i++) {
        printf("[C Engine] Allowed app path: %s\n", allowed[i]);
    }
    allowed_paths = malloc(count * sizeof(char*));
    if (allowed_paths == NULL)
        exit(1);
    
    for (int i = 0; i < count; i++) {
        if (allowed[i] != NULL)
            allowed_paths[i] = strdup(allowed[i]);
        else
            exit(1);
    }
    allowed_paths_ct = count;
    is_blocking_active = true;
    // TODO: actually call the check_running_process such that it actually does things
   
}

void stop_blocking_session(void) {
    printf("[C Engine] Session stopped.\n");
    is_blocking_active = false;
    if (allowed_paths == NULL)
        exit(1);
    for (int i = 0; i < allowed_paths_ct; i++) {
        if (allowed_paths[i] == NULL)
            exit(1);
        free(allowed_paths[i]);
    }
    free(allowed_paths);
    allowed_paths = NULL;
    allowed_paths_ct = 0;
}

void check_and_enforce_rules(const char **allowed_paths, int32_t ct)
{
    // TODO: implement
    puts("(placeholder)");
    printf("Allowed count: %d\n", ct);
}
