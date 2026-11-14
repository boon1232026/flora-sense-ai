#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "api/router.h"
#include "api/http_server.h"
#include "core/sim_store.h"
#include "device_commands/command_policy.h"
#include "services/pump_service.h"

static int print_health(void)
{
    char response[256];
    int status = api_route_request("GET", "/healthz", NULL, NULL, response, sizeof(response));
    printf("%s\n", response);
    return status == 200 ? 0 : 1;
}

static int demo_command(void)
{
    flora_pump_command_t command = {
        .command_id = "11111111-2222-3333-4444-555555555555",
        .device_id = "FLORA-ESP32-DEV",
        .plant_id = "PLANT-DEV",
        .idempotency_key = "demo-key-1",
        .mode = FLORA_MODE_MANUAL,
        .start = true,
        .duration_seconds = 30,
        .issued_at_unix_ms = 1000,
        .expires_at_unix_ms = 61000,
    };
    flora_policy_context_t context = {
        .mode = FLORA_MODE_MANUAL,
        .test_interlock = false,
        .max_run_seconds = 120,
        .cooldown_seconds = 0,
        .last_completed_at_unix_ms = 0,
        .soil_valid = true,
        .cloud_authenticated = true,
    };
    char reason[FLORA_REASON_MAX] = {0};
    pump_service_result_t result = pump_service_submit(&command, &context, 2000, reason, sizeof(reason));
    printf("command result=%d reason=%s\n", result, reason);
    return result == PUMP_SERVICE_ACCEPTED ? 0 : 1;
}

int main(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "--health") == 0) {
        sim_store_init();
        return print_health();
    }
    if (argc > 1 && strcmp(argv[1], "--demo-command") == 0) {
        sim_store_init();
        return demo_command();
    }
    int port = 18080;
    if (argc > 2 && strcmp(argv[1], "--serve") == 0) port = atoi(argv[2]);
    sim_store_init();
    return http_server_run(port);
}
