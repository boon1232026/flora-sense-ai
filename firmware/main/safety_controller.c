#include "safety_controller.h"

#include <string.h>

static flora_safety_policy_t s_policy = {
    .mode = FLORA_MODE_TEST,
    .hardware_interlock_enabled = true,
    .pump_output_enabled = false,
    .max_run_seconds = CONFIG_FLORA_MAX_PUMP_RUN_MS / 1000,
};
static char s_command_history[CONFIG_FLORA_COMMAND_HISTORY_SIZE][FLORA_COMMAND_ID_MAX];
static size_t s_history_next;

void safety_controller_init(flora_mode_t initial_mode)
{
    memset(&s_policy, 0, sizeof(s_policy));
    s_policy.mode = initial_mode;
    s_policy.hardware_interlock_enabled = (initial_mode == FLORA_MODE_TEST);
    s_policy.pump_output_enabled = (initial_mode != FLORA_MODE_TEST);
    s_policy.max_run_seconds = CONFIG_FLORA_MAX_PUMP_RUN_MS / 1000;
    memset(s_command_history, 0, sizeof(s_command_history));
    s_history_next = 0;
}

void safety_controller_set_mode(flora_mode_t mode)
{
    s_policy.mode = mode;
    s_policy.pump_output_enabled = (mode != FLORA_MODE_TEST);
    if (mode == FLORA_MODE_TEST) {
        s_policy.hardware_interlock_enabled = true;
    }
}

flora_mode_t safety_controller_get_mode(void)
{
    return s_policy.mode;
}

void safety_controller_set_hardware_interlock(bool enabled)
{
    s_policy.hardware_interlock_enabled = enabled;
}

bool safety_controller_interlock_active(void)
{
    return s_policy.hardware_interlock_enabled || s_policy.mode == FLORA_MODE_TEST;
}

void safety_controller_note_command_id(const char *command_id)
{
    if (!command_id || !command_id[0]) {
        return;
    }
    strncpy(s_command_history[s_history_next], command_id, FLORA_COMMAND_ID_MAX - 1);
    s_command_history[s_history_next][FLORA_COMMAND_ID_MAX - 1] = '\0';
    s_history_next = (s_history_next + 1) % CONFIG_FLORA_COMMAND_HISTORY_SIZE;
}

bool safety_controller_seen_command_id(const char *command_id)
{
    if (!command_id || !command_id[0]) {
        return true;
    }
    for (size_t i = 0; i < CONFIG_FLORA_COMMAND_HISTORY_SIZE; ++i) {
        if (s_command_history[i][0] && strncmp(s_command_history[i], command_id, FLORA_COMMAND_ID_MAX) == 0) {
            return true;
        }
    }
    return false;
}

flora_safety_decision_t safety_controller_validate_command(
    const flora_pump_command_t *command,
    const char *expected_device_id,
    int64_t now_unix_ms,
    const flora_sensor_reading_t *current_reading)
{
    flora_safety_decision_t decision = {.allowed = false, .reason = FLORA_REJECT_NONE};
    if (!command || !expected_device_id || !command->command_id[0] || !command->device_id[0] || !command->action_valid) {
        decision.reason = FLORA_REJECT_MALFORMED;
        return decision;
    }
    if (command->retained_delivery || strncmp(command->device_id, expected_device_id, FLORA_DEVICE_ID_MAX) != 0) {
        decision.reason = FLORA_REJECT_MALFORMED;
        return decision;
    }
    if (safety_controller_seen_command_id(command->command_id)) {
        decision.reason = FLORA_REJECT_DUPLICATE;
        return decision;
    }
    if (now_unix_ms <= 0) {
        decision.reason = FLORA_REJECT_CLOCK_NOT_SYNCED;
        return decision;
    }
    if (command->expires_at_unix_ms <= now_unix_ms) {
        decision.reason = FLORA_REJECT_EXPIRED;
        return decision;
    }
    if (safety_controller_interlock_active() || s_policy.mode == FLORA_MODE_TEST) {
        decision.reason = FLORA_REJECT_HARDWARE_INTERLOCK;
        return decision;
    }
    if (command->requested_mode != s_policy.mode) {
        decision.reason = FLORA_REJECT_INVALID_MODE;
        return decision;
    }
    if (command->duration_seconds == 0 || command->duration_seconds > s_policy.max_run_seconds) {
        decision.reason = FLORA_REJECT_DURATION;
        return decision;
    }
    if (current_reading && !current_reading->soil_valid && s_policy.mode == FLORA_MODE_AUTO) {
        decision.reason = FLORA_REJECT_SENSOR_FAULT;
        return decision;
    }

    decision.allowed = true;
    return decision;
}

bool safety_controller_pump_output_allowed(void)
{
    return s_policy.pump_output_enabled && !safety_controller_interlock_active();
}
