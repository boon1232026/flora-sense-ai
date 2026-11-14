#ifndef SAFETY_CONTROLLER_H
#define SAFETY_CONTROLLER_H

#include "flora_types.h"

void safety_controller_init(flora_mode_t initial_mode);
void safety_controller_set_mode(flora_mode_t mode);
flora_mode_t safety_controller_get_mode(void);
void safety_controller_set_hardware_interlock(bool enabled);
bool safety_controller_interlock_active(void);
void safety_controller_note_command_id(const char *command_id);
bool safety_controller_seen_command_id(const char *command_id);
flora_safety_decision_t safety_controller_validate_command(
    const flora_pump_command_t *command,
    const char *expected_device_id,
    int64_t now_unix_ms,
    const flora_sensor_reading_t *current_reading);
bool safety_controller_pump_output_allowed(void);

#endif
