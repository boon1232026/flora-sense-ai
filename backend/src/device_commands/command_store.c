#include "command_store.h"

#include "command_policy.h"

#include <stdio.h>
#include <string.h>

#define STORE_CAPACITY 128

typedef struct {
    char command_id[FLORA_ID_MAX];
    char device_id[FLORA_ID_MAX];
    char idempotency_key[FLORA_IDEMPOTENCY_KEY_MAX];
    flora_command_status_t status;
    char reason[FLORA_REASON_MAX];
} store_row_t;

static store_row_t s_rows[STORE_CAPACITY];
static size_t s_count;

static int find_command(const char *command_id)
{
    for (size_t i = 0; i < s_count; ++i) {
        if (strncmp(s_rows[i].command_id, command_id, FLORA_ID_MAX) == 0) return (int)i;
    }
    return -1;
}

void command_store_reset(void)
{
    memset(s_rows, 0, sizeof(s_rows));
    s_count = 0;
}

bool command_store_register(const flora_pump_command_t *command,
                            char *existing_command_id,
                            size_t id_size,
                            flora_command_status_t *duplicate_status)
{
    if (!command || !command_policy_is_valid_uuid(command->command_id)) return false;
    for (size_t i = 0; i < s_count; ++i) {
        bool same_id = strncmp(s_rows[i].command_id, command->command_id, FLORA_ID_MAX) == 0;
        bool same_key = strncmp(s_rows[i].device_id, command->device_id, FLORA_ID_MAX) == 0 &&
                        strncmp(s_rows[i].idempotency_key, command->idempotency_key, FLORA_IDEMPOTENCY_KEY_MAX) == 0;
        if (same_id || same_key) {
            if (existing_command_id && id_size) {
                snprintf(existing_command_id, id_size, "%s", s_rows[i].command_id);
            }
            if (duplicate_status) *duplicate_status = s_rows[i].status;
            return false;
        }
    }
    if (s_count >= STORE_CAPACITY) return false;
    store_row_t *row = &s_rows[s_count++];
    snprintf(row->command_id, sizeof(row->command_id), "%s", command->command_id);
    snprintf(row->device_id, sizeof(row->device_id), "%s", command->device_id);
    snprintf(row->idempotency_key, sizeof(row->idempotency_key), "%s", command->idempotency_key);
    row->status = FLORA_COMMAND_CREATED;
    return true;
}

flora_command_status_t command_store_status(const char *command_id)
{
    int found = command_id ? find_command(command_id) : -1;
    return found >= 0 ? s_rows[found].status : FLORA_COMMAND_CREATED;
}

void command_store_set_status(const char *command_id, flora_command_status_t status, const char *reason)
{
    int found = command_id ? find_command(command_id) : -1;
    if (found < 0) return;
    s_rows[found].status = status;
    snprintf(s_rows[found].reason, FLORA_REASON_MAX, "%s", reason ? reason : "");
}
