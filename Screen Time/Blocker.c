//
//  Blocker.c
//  Screen Time
//
//  Created by BUQI DONG on 2/9/2026.
//

#include "Blocker.h"

#include "Blocker.h"

void start_blocking_session(int duration_seconds, const char **allowed_paths, int count) {
    printf("[C Engine] Session started for %d seconds.\n", duration_seconds);
    for (int i = 0; i < count; i++) {
        printf("[C Engine] Allowed app path: %s\n", allowed_paths[i]);
    }
    // TODO: implement low level stuff (find sys libraries later)
}

void stop_blocking_session(void) {
    printf("[C Engine] Session stopped.\n");
}
