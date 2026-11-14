#ifndef PUMP_CONTROLLER_H
#define PUMP_CONTROLLER_H

#include "flora_types.h"

void pump_controller_init(void);
void pump_controller_tick(int64_t now_unix_ms);
bool pump_controller_request_start(uint32_t duration_seconds);
void pump_controller_request_stop(const char *reason);
void pump_controller_force_safe_off(const char *reason);
flora_pump_state_t pump_controller_state(void);
uint32_t pump_controller_remaining_seconds(int64_t now_unix_ms);

#endif
