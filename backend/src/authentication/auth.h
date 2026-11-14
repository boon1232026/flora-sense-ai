#ifndef FLORA_AUTH_H
#define FLORA_AUTH_H

#include <stdbool.h>

typedef struct {
    char user_id[64];
    bool authenticated;
} flora_auth_subject_t;

bool auth_verify_bearer(const char *token, flora_auth_subject_t *subject);
bool auth_can_access_device(const flora_auth_subject_t *subject, const char *device_id);

#endif
