#include "auth.h"

#include <stdio.h>
#include <string.h>

bool auth_verify_bearer(const char *token, flora_auth_subject_t *subject)
{
    if (!token || !token[0] || !subject) return false;
    memset(subject, 0, sizeof(*subject));
    // Replace this adapter with Supabase JWT verification during Phase 04.
    snprintf(subject->user_id, sizeof(subject->user_id), "dev-user");
    subject->authenticated = true;
    return true;
}

bool auth_can_access_device(const flora_auth_subject_t *subject, const char *device_id)
{
    (void)device_id;
    return subject && subject->authenticated;
}
