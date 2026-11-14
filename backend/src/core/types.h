#ifndef FLORA_BACKEND_TYPES_H
#define FLORA_BACKEND_TYPES_H

#include <stdbool.h>
#include <stdint.h>
#include <time.h>

#define FLORA_ID_MAX 64
#define FLORA_REASON_MAX 96
#define FLORA_IDEMPOTENCY_KEY_MAX 128

typedef enum {
    FLORA_MODE_TEST = 0,
    FLORA_MODE_MANUAL,
    FLORA_MODE_AUTO
} flora_mode_t;

typedef enum {
    FLORA_COMMAND_CREATED = 0,
    FLORA_COMMAND_QUEUED,
    FLORA_COMMAND_ACCEPTED,
    FLORA_COMMAND_REJECTED,
    FLORA_COMMAND_DUPLICATE,
    FLORA_COMMAND_EXPIRED,
    FLORA_COMMAND_STARTED,
    FLORA_COMMAND_COMPLETED,
    FLORA_COMMAND_FAILED,
    FLORA_COMMAND_CANCELLED
} flora_command_status_t;

typedef enum {
    FLORA_REJECT_OK = 0,
    FLORA_REJECT_TEST_MODE,
    FLORA_REJECT_EXPIRED,
    FLORA_REJECT_DUPLICATE,
    FLORA_REJECT_INVALID_MODE,
    FLORA_REJECT_DURATION,
    FLORA_REJECT_UNAUTHORIZED,
    FLORA_REJECT_SENSOR_FAULT,
    FLORA_REJECT_COOLDOWN
} flora_reject_reason_t;

typedef struct {
    char command_id[FLORA_ID_MAX];
    char device_id[FLORA_ID_MAX];
    char plant_id[FLORA_ID_MAX];
    char idempotency_key[FLORA_IDEMPOTENCY_KEY_MAX];
    flora_mode_t mode;
    bool start;
    uint32_t duration_seconds;
    int64_t issued_at_unix_ms;
    int64_t expires_at_unix_ms;
} flora_pump_command_t;

typedef struct {
    bool allowed;
    flora_reject_reason_t reason;
} flora_policy_result_t;

typedef struct {
    flora_mode_t mode;
    bool test_interlock;
    uint32_t max_run_seconds;
    uint32_t cooldown_seconds;
    int64_t last_completed_at_unix_ms;
    bool soil_valid;
    bool cloud_authenticated;
} flora_policy_context_t;

const char *flora_command_status_name(flora_command_status_t status);
const char *flora_reject_reason_name(flora_reject_reason_t reason);
const char *flora_mode_name(flora_mode_t mode);
flora_mode_t flora_mode_from_name(const char *name);

#endif
