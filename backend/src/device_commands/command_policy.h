#ifndef COMMAND_POLICY_H
#define COMMAND_POLICY_H

#include "../core/types.h"

flora_policy_result_t command_policy_validate(
    const flora_pump_command_t *command,
    const flora_policy_context_t *context,
    int64_t now_unix_ms);

bool command_policy_is_valid_uuid(const char *value);
int64_t command_policy_parse_rfc3339_ms(const char *value);

#endif
