#include "command_policy.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

bool command_policy_is_valid_uuid(const char *value)
{
    if (!value || strlen(value) != 36) return false;
    for (size_t i = 0; i < 36; ++i) {
        if (i == 8 || i == 13 || i == 18 || i == 23) {
            if (value[i] != '-') return false;
        } else if (!isxdigit((unsigned char)value[i])) {
            return false;
        }
    }
    return true;
}

flora_policy_result_t command_policy_validate(
    const flora_pump_command_t *command,
    const flora_policy_context_t *context,
    int64_t now_unix_ms)
{
    flora_policy_result_t result = {.allowed = false, .reason = FLORA_REJECT_OK};
    if (!command || !context || !command_policy_is_valid_uuid(command->command_id)) {
        result.reason = FLORA_REJECT_INVALID_MODE;
        return result;
    }
    if (context->mode == FLORA_MODE_TEST || context->test_interlock) {
        result.reason = FLORA_REJECT_TEST_MODE;
        return result;
    }
    if (command->mode != context->mode) {
        result.reason = FLORA_REJECT_INVALID_MODE;
        return result;
    }
    if (!context->cloud_authenticated) {
        result.reason = FLORA_REJECT_UNAUTHORIZED;
        return result;
    }
    if (command->expires_at_unix_ms <= now_unix_ms) {
        result.reason = FLORA_REJECT_EXPIRED;
        return result;
    }
    if (!command->start) {
        result.allowed = true;
        return result;
    }
    if (command->duration_seconds == 0 || command->duration_seconds > context->max_run_seconds) {
        result.reason = FLORA_REJECT_DURATION;
        return result;
    }
    if (context->mode == FLORA_MODE_AUTO && !context->soil_valid) {
        result.reason = FLORA_REJECT_SENSOR_FAULT;
        return result;
    }
    if (context->last_completed_at_unix_ms > 0) {
        int64_t cooldown_end = context->last_completed_at_unix_ms + (int64_t)context->cooldown_seconds * 1000;
        if (now_unix_ms < cooldown_end) {
            result.reason = FLORA_REJECT_COOLDOWN;
            return result;
        }
    }
    result.allowed = true;
    return result;
}

static int two_digits(const char *value)
{
    if (!isdigit((unsigned char)value[0]) || !isdigit((unsigned char)value[1])) return -1;
    return (value[0] - '0') * 10 + (value[1] - '0');
}

int64_t command_policy_parse_rfc3339_ms(const char *value)
{
    if (!value || strlen(value) < 20) return 0;
    struct tm tm = {0};
    tm.tm_year = (value[0] - '0') * 1000 + (value[1] - '0') * 100 + (value[2] - '0') * 10 + (value[3] - '0') - 1900;
    tm.tm_mon = two_digits(value + 5) - 1;
    tm.tm_mday = two_digits(value + 8);
    tm.tm_hour = two_digits(value + 11);
    tm.tm_min = two_digits(value + 14);
    tm.tm_sec = two_digits(value + 17);
    if (tm.tm_mon < 0 || tm.tm_mday < 0 || tm.tm_hour < 0 || tm.tm_min < 0 || tm.tm_sec < 0) return 0;
#ifdef _GNU_SOURCE
    time_t seconds = timegm(&tm);
#else
    char *old_tz = getenv("TZ");
    setenv("TZ", "UTC", 1);
    tzset();
    time_t seconds = mktime(&tm);
    if (old_tz) setenv("TZ", old_tz, 1); else unsetenv("TZ");
    tzset();
#endif
    return seconds < 0 ? 0 : (int64_t)seconds * 1000;
}
