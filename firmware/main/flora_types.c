#include "flora_types.h"

const char *flora_mode_name(flora_mode_t mode)
{
    switch (mode) {
    case FLORA_MODE_TEST: return "TEST";
    case FLORA_MODE_MANUAL: return "MANUAL";
    case FLORA_MODE_AUTO: return "AUTO";
    default: return "UNKNOWN";
    }
}

const char *flora_reject_reason_name(flora_reject_reason_t reason)
{
    switch (reason) {
    case FLORA_REJECT_NONE: return "NONE";
    case FLORA_REJECT_TEST_MODE: return "TEST_MODE";
    case FLORA_REJECT_EXPIRED: return "EXPIRED";
    case FLORA_REJECT_DUPLICATE: return "DUPLICATE";
    case FLORA_REJECT_MALFORMED: return "MALFORMED";
    case FLORA_REJECT_INVALID_MODE: return "INVALID_MODE";
    case FLORA_REJECT_DURATION: return "DURATION";
    case FLORA_REJECT_HARDWARE_INTERLOCK: return "HARDWARE_INTERLOCK";
    case FLORA_REJECT_SENSOR_FAULT: return "SENSOR_FAULT";
    case FLORA_REJECT_CLOCK_NOT_SYNCED: return "CLOCK_NOT_SYNCED";
    default: return "UNKNOWN";
    }
}
