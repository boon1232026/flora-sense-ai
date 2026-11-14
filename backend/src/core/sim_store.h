#ifndef FLORA_SIM_STORE_H
#define FLORA_SIM_STORE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "types.h"

#define SIM_MAX_READINGS 120
#define SIM_MAX_PLANTS 16
#define SIM_MAX_DEVICE_CHANNELS 4
#define SIM_MAX_IMAGES 16
#define SIM_MAX_ALERTS 16
#define SIM_JSON_BUFFER 8192

typedef struct {
    int64_t sampled_at_unix_ms;
    char device_id[FLORA_ID_MAX];
    char plant_id[FLORA_ID_MAX];
    double soil_moisture;
    double air_temperature;
    double air_humidity;
    double leaf_temperature;
    bool soil_valid;
    bool air_valid;
    bool leaf_valid;
    int ai_risk_score;
    bool ai_risk_valid;
} sim_reading_t;

typedef struct {
    char command_id[FLORA_ID_MAX];
    char device_id[FLORA_ID_MAX];
    char plant_id[FLORA_ID_MAX];
    flora_mode_t mode;
    bool start;
    uint32_t duration_seconds;
    int64_t issued_at_unix_ms;
    int64_t expires_at_unix_ms;
    flora_command_status_t status;
    char reason[FLORA_REASON_MAX];
    bool pending;
} sim_command_t;

typedef struct {
    char id[FLORA_ID_MAX];
    char name[96];
    char zone[64];
    char device_id[FLORA_ID_MAX];
    char image_asset[128];
    char image_path[192];
    char health_status[16];
    double soil_moisture;
    uint8_t sensor_channel;
    bool soil_valid;
} sim_plant_t;

typedef struct {
    char id[FLORA_ID_MAX];
    char plant_id[FLORA_ID_MAX];
    char image_path[192];
    char status[24];
    int64_t captured_at_unix_ms;
    double exg;
    double green_ratio;
    bool quality_ok;
} sim_image_t;

typedef struct {
    char id[FLORA_ID_MAX];
    char title[128];
    char message[512];
    char severity[24];
    int64_t created_at_unix_ms;
    bool acknowledged;
} sim_alert_t;

typedef struct {
    bool notify_app;
    bool notify_email;
    bool notify_line;
    bool pump_enabled;
    bool auto_irrigation;
    char language[16];
    char display_mode[32];
    double auto_start_moisture;
    double auto_stop_moisture;
    uint32_t auto_run_seconds;
    double high_risk_score;
} sim_settings_t;

typedef struct {
    sim_reading_t readings[SIM_MAX_READINGS];
    size_t reading_count;
    size_t reading_next;
    sim_plant_t plants[SIM_MAX_PLANTS];
    size_t plant_count;
    sim_image_t images[SIM_MAX_IMAGES];
    size_t image_count;
    size_t image_next;
    sim_alert_t alerts[SIM_MAX_ALERTS];
    size_t alert_count;
    size_t alert_next;
    sim_settings_t settings;
    bool reboot_pending;
    char device_id[FLORA_ID_MAX];
    char device_name[64];
    char plant_id[FLORA_ID_MAX];
    char firmware_version[24];
    char device_ip[40];
    int64_t last_seen_unix_ms;
    int battery_percent;
    char mode_name[16];
    flora_mode_t mode;
    char pump_state[16];
    uint32_t pump_remaining_seconds;
    char risk_level[16];
    int risk_score;
    char recommendation[512];
    char model_version[64];
    char ai_plant_id[FLORA_ID_MAX];
    double exg;
    double green_ratio;
    double leaf_air_delta_c;
    double moisture_trend_per_hour;
    bool image_metrics_valid;
    bool ai_result_received;
    char last_command_id[FLORA_ID_MAX];
    char last_command_status[32];
    char last_command_reason[FLORA_REASON_MAX];
    int64_t last_command_ack_at_unix_ms;
    sim_command_t pending_command;
} sim_state_t;

void sim_store_init(void);
const char *sim_store_expected_device_id(void);
int64_t sim_now_ms(void);
void sim_store_add_reading(const sim_reading_t *reading);
const sim_reading_t *sim_store_latest_reading(void);
void sim_store_set_ai_result(const char *plant_id, const char *level, int score,
                             const char *recommendation, const char *model_version,
                             double exg, double green_ratio,
                             double leaf_air_delta_c, double moisture_trend_per_hour,
                             bool image_metrics_valid);
bool sim_store_submit_command(const char *device_id, const char *plant_id,
                              const char *action, uint32_t duration_seconds,
                              char *reason, size_t reason_size);
bool sim_store_pop_pending_command(const char *device_id, sim_command_t *out);
void sim_store_update_pump_status(const char *state, uint32_t remaining_seconds);
void sim_store_update_device_status(const char *device_id, const char *name,
                                    const char *firmware_version, const char *ip,
                                    int battery_percent);
bool sim_store_register_device(const char *id, const char *name,
                               char *error, size_t error_size);
bool sim_store_update_device(const char *id, const char *new_id, const char *name,
                             char *error, size_t error_size);
bool sim_store_delete_device(const char *id, char *error, size_t error_size);
const sim_state_t *sim_store_state(void);
int sim_store_available_sensor_channel(const char *device_id);
bool sim_store_add_plant(const char *name, const char *zone, const char *device_id,
                         const char *image_asset, const char *image_path,
                         const char *health_status, double soil_moisture,
                         char *id, size_t id_size);
bool sim_store_update_plant(const char *id, const char *name, const char *zone,
                            const char *device_id, const char *image_path,
                            const char *health_status, int *sensor_channel);
bool sim_store_delete_plant(const char *id);
bool sim_store_add_image(const char *plant_id, const char *image_path, const char *status,
                         double exg, double green_ratio, char *id, size_t id_size);
bool sim_store_acknowledge_alert(const char *id);
void sim_store_record_command_ack(const char *command_id, const char *status, const char *reason);
bool sim_store_update_image_metrics(const char *id, const char *status, double exg,
                                    double green_ratio, bool quality_ok);
bool sim_store_update_image(const char *id, const char *plant_id, const char *image_path);
bool sim_store_delete_image(const char *id);
bool sim_store_update_settings(const char *body, char *error, size_t error_size);
bool sim_store_set_mode(const char *mode_name, char *error, size_t error_size);
void sim_store_request_reboot(void);
bool sim_store_pop_reboot(void);

int sim_store_dashboard_json(char *out, size_t size);
int sim_store_readings_json(char *out, size_t size);
int sim_store_plants_json(char *out, size_t size);
int sim_store_images_json(char *out, size_t size);
int sim_store_alerts_json(char *out, size_t size);
int sim_store_devices_json(char *out, size_t size);
int sim_store_settings_json(char *out, size_t size);
int sim_store_report_json(const char *range_name, char *out, size_t size);
int sim_store_pending_command_json(const char *device_id, char *out, size_t size);

#endif
