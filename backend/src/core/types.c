#include "types.h"

#include <string.h>

const char *flora_command_status_name(flora_command_status_t status)
{
    switch (status) {
    case FLORA_COMMAND_CREATED: return "created";
    case FLORA_COMMAND_QUEUED: return "queued";
    case FLORA_COMMAND_ACCEPTED: return "accepted";
    case FLORA_COMMAND_REJECTED: return "rejected";
    case FLORA_COMMAND_DUPLICATE: return "duplicate";
    case FLORA_COMMAND_EXPIRED: return "expired";
    case FLORA_COMMAND_STARTED: return "started";
    case FLORA_COMMAND_COMPLETED: return "completed";
    case FLORA_COMMAND_FAILED: return "failed";
    case FLORA_COMMAND_CANCELLED: return "cancelled";
    default: return "unknown";
    }
}

const char *flora_reject_reason_name(flora_reject_reason_t reason)
{
    switch (reason) {
    case FLORA_REJECT_OK: return "OK";
    case FLORA_REJECT_TEST_MODE: return "TEST_MODE";
    case FLORA_REJECT_EXPIRED: return "EXPIRED";
    case FLORA_REJECT_DUPLICATE: return "DUPLICATE";
    case FLORA_REJECT_INVALID_MODE: return "INVALID_MODE";
    case FLORA_REJECT_DURATION: return "DURATION";
    case FLORA_REJECT_UNAUTHORIZED: return "UNAUTHORIZED";
    case FLORA_REJECT_SENSOR_FAULT: return "SENSOR_FAULT";
    case FLORA_REJECT_COOLDOWN: return "COOLDOWN";
    default: return "UNKNOWN";
    }
}

const char *flora_mode_name(flora_mode_t mode)
{
    switch (mode) {
    case FLORA_MODE_TEST: return "TEST";
    case FLORA_MODE_MANUAL: return "MANUAL";
    case FLORA_MODE_AUTO: return "AUTO";
    default: return "UNKNOWN";
    }
}

flora_mode_t flora_mode_from_name(const char *name)
{
    if (name && strcmp(name, "MANUAL") == 0) return FLORA_MODE_MANUAL;
    if (name && strcmp(name, "AUTO") == 0) return FLORA_MODE_AUTO;
    return FLORA_MODE_TEST;
}
