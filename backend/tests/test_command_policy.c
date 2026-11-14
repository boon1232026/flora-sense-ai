#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "../src/device_commands/command_policy.h"
#include "../src/device_commands/command_store.h"
#include "../src/services/pump_service.h"

static flora_pump_command_t valid_command(void)
{
    flora_pump_command_t command = {0};
    snprintf(command.command_id, sizeof(command.command_id), "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
    snprintf(command.device_id, sizeof(command.device_id), "device-1");
    snprintf(command.plant_id, sizeof(command.plant_id), "plant-1");
    snprintf(command.idempotency_key, sizeof(command.idempotency_key), "key-1");
    command.mode = FLORA_MODE_MANUAL;
    command.start = true;
    command.duration_seconds = 30;
    command.issued_at_unix_ms = 1000;
    command.expires_at_unix_ms = 60000;
    return command;
}

static flora_policy_context_t manual_context(void)
{
    flora_policy_context_t context = {0};
    context.mode = FLORA_MODE_MANUAL;
    context.max_run_seconds = 120;
    context.soil_valid = true;
    context.cloud_authenticated = true;
    return context;
}

static void test_policy_boundaries(void)
{
    flora_pump_command_t command = valid_command();
    flora_policy_context_t context = manual_context();
    flora_policy_result_t result = command_policy_validate(&command, &context, 2000);
    assert(result.allowed);

    command.duration_seconds = 121;
    result = command_policy_validate(&command, &context, 2000);
    assert(!result.allowed && result.reason == FLORA_REJECT_DURATION);
    command.duration_seconds = 30;

    context.mode = FLORA_MODE_TEST;
    result = command_policy_validate(&command, &context, 2000);
    assert(!result.allowed && result.reason == FLORA_REJECT_TEST_MODE);
    context = manual_context();

    result = command_policy_validate(&command, &context, 60001);
    assert(!result.allowed && result.reason == FLORA_REJECT_EXPIRED);
}

static void test_idempotency(void)
{
    command_store_reset();
    flora_pump_command_t command = valid_command();
    flora_policy_context_t context = manual_context();
    char reason[FLORA_REASON_MAX] = {0};
    assert(pump_service_submit(&command, &context, 2000, reason, sizeof(reason)) == PUMP_SERVICE_ACCEPTED);
    assert(pump_service_submit(&command, &context, 2000, reason, sizeof(reason)) == PUMP_SERVICE_DUPLICATE);
}

int main(void)
{
    test_policy_boundaries();
    test_idempotency();
    puts("backend command policy tests passed");
    return 0;
}
