#include "pump_service.h"

#include "../device_commands/command_store.h"
#include <stdio.h>

pump_service_result_t pump_service_submit(
    const flora_pump_command_t *command,
    const flora_policy_context_t *context,
    int64_t now_unix_ms,
    char *reason,
    size_t reason_size)
{
    if (!command || !reason || reason_size == 0) return PUMP_SERVICE_REJECTED;
    char existing[FLORA_ID_MAX] = {0};
    flora_command_status_t duplicate_status = FLORA_COMMAND_CREATED;
    if (!command_store_register(command, existing, sizeof(existing), &duplicate_status)) {
        snprintf(reason, reason_size, "DUPLICATE:%s:%s", existing, flora_command_status_name(duplicate_status));
        return PUMP_SERVICE_DUPLICATE;
    }

    flora_policy_result_t policy = command_policy_validate(command, context, now_unix_ms);
    if (!policy.allowed) {
        command_store_set_status(command->command_id, FLORA_COMMAND_REJECTED, flora_reject_reason_name(policy.reason));
        snprintf(reason, reason_size, "%s", flora_reject_reason_name(policy.reason));
        return PUMP_SERVICE_REJECTED;
    }

    command_store_set_status(command->command_id, FLORA_COMMAND_QUEUED, "NONE");
    snprintf(reason, reason_size, "QUEUED");
    return PUMP_SERVICE_ACCEPTED;
}
