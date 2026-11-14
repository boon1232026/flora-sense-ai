#ifndef PUMP_SERVICE_H
#define PUMP_SERVICE_H

#include "../core/types.h"
#include "../device_commands/command_policy.h"

typedef enum {
    PUMP_SERVICE_ACCEPTED = 0,
    PUMP_SERVICE_DUPLICATE,
    PUMP_SERVICE_REJECTED
} pump_service_result_t;

pump_service_result_t pump_service_submit(
    const flora_pump_command_t *command,
    const flora_policy_context_t *context,
    int64_t now_unix_ms,
    char *reason,
    size_t reason_size);

#endif
