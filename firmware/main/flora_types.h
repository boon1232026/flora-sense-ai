#ifndef FLORA_TYPES_H
#define FLORA_TYPES_H

#include <stdbool.h>
#include <stdint.h>
#include "flora_config.h"

typedef enum {
    FLORA_MODE_TEST = 0,
    FLORA_MODE_MANUAL,
    FLORA_MODE_AUTO
} flora_mode_t;

typedef enum {
    FLORA_PUMP_OFF = 0,
    FLORA_PUMP_RUNNING,
    FLORA_PUMP_FAULT
} flora_pump_state_t;

typedef enum {
    FLORA_REJECT_NONE = 0,
    FLORA_REJECT_TEST_MODE,
    FLORA_REJECT_EXPIRED,
    FLORA_REJECT_DUPLICATE,
    FLORA_REJECT_MALFORMED,
    FLORA_REJECT_INVALID_MODE,
    FLORA_REJECT_DURATION,
    FLORA_REJECT_HARDWARE_INTERLOCK,
    FLORA_REJECT_SENSOR_FAULT,
    FLORA_REJECT_CLOCK_NOT_SYNCED
} flora_reject_reason_t;

typedef struct {
    float soil_moisture_percent;
    float air_temperature_c;
    float air_humidity_percent;
    float leaf_temperature_c;
    float supply_voltage;
    bool soil_valid;
    bool air_valid;
    bool leaf_valid;
    int64_t sampled_at_unix_ms;
} flora_sensor_reading_t;

typedef struct {
    char command_id[FLORA_COMMAND_ID_MAX];
    char device_id[FLORA_DEVICE_ID_MAX];
    char plant_id[FLORA_PLANT_ID_MAX];
    int64_t issued_at_unix_ms;
    int64_t expires_at_unix_ms;
    flora_mode_t requested_mode;
    bool start;
    bool action_valid;
    uint32_t duration_seconds;
    bool retained_delivery;
} flora_pump_command_t;

typedef struct {
    bool allowed;
    flora_reject_reason_t reason;
} flora_safety_decision_t;

typedef struct {
    flora_mode_t mode;
    bool hardware_interlock_enabled;
    bool pump_output_enabled;
    uint32_t max_run_seconds;
} flora_safety_policy_t;

typedef struct {
    flora_mode_t mode;
    bool wifi_connected;
    bool mqtt_connected;
    flora_pump_state_t pump_state;
    uint32_t pump_remaining_seconds;
    char firmware_version[32];
} flora_device_status_t;

const char *flora_mode_name(flora_mode_t mode);
const char *flora_reject_reason_name(flora_reject_reason_t reason);

#endif
