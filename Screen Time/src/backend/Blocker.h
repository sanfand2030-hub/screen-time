//
//  Blocker.h
//  Screen Time
//
//  Created by BUQI DONG on 2/9/2026.
//

#ifndef Blocker_h
#define Blocker_h

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

// Starts blocking non-allowed apps for the specified duration (in seconds)
void start_blocking_session(int duration_seconds, const char **allowed_paths, int count);

// Stops active monitoring loop
void stop_blocking_session(void);

void check_and_enforce_rules(const char **allowed_paths, int32_t ct);

#endif /* Blocker_h */
