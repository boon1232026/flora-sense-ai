#include "flora_mqtt.h"

#include <stdio.h>
#include <string.h>

#include "cJSON.h"
#include "device_config.h"
#include "device_time.h"
#include "esp_log.h"
#include "esp_system.h"
#include <mqtt_client.h>
#include "pump_controller.h"
#include "safety_controller.h"

#define TAG "flora_mqtt"

static esp_mqtt_client_handle_t s_client;
static bool s_connected;

static void topic_for(char *out, size_t size, const char *leaf)
{
    snprintf(out, size, "flora/devices/%s/%s", device_config_id(), leaf);
}

static esp_err_t publish_json(const char *leaf, cJSON *payload, int qos, bool retained)
{
    char topic[FLORA_MQTT_TOPIC_MAX];
    char *body = cJSON_PrintUnformatted(payload);
    if (!body) return ESP_ERR_NO_MEM;
    topic_for(topic, sizeof(topic), leaf);
    int result = esp_mqtt_client_publish(s_client, topic, body, 0, qos, retained);
    cJSON_free(body);
    return result >= 0 ? ESP_OK : ESP_FAIL;
}

static void handle_command_json(const char *data, int len, bool retained)
{
    cJSON *root = cJSON_ParseWithLength(data, len);
    if (!root) {
        flora_mqtt_publish_command_ack("unknown", "REJECTED", "MALFORMED");
        return;
    }
    flora_pump_command_t command = {0};
    cJSON *item = cJSON_GetObjectItem(root, "command_id");
    if (cJSON_IsString(item)) strlcpy(command.command_id, item->valuestring, sizeof(command.command_id));
    item = cJSON_GetObjectItem(root, "device_id");
    if (cJSON_IsString(item)) strlcpy(command.device_id, item->valuestring, sizeof(command.device_id));
    item = cJSON_GetObjectItem(root, "plant_id");
    if (cJSON_IsString(item)) strlcpy(command.plant_id, item->valuestring, sizeof(command.plant_id));
    item = cJSON_GetObjectItem(root, "issued_at");
    if (cJSON_IsString(item)) command.issued_at_unix_ms = device_time_parse_utc_iso_ms(item->valuestring);
    item = cJSON_GetObjectItem(root, "expires_at");
    if (cJSON_IsString(item)) command.expires_at_unix_ms = device_time_parse_utc_iso_ms(item->valuestring);
    item = cJSON_GetObjectItem(root, "duration_seconds");
    command.duration_seconds = cJSON_IsNumber(item) ? (uint32_t)item->valuedouble : 0;
    item = cJSON_GetObjectItem(root, "mode");
    command.requested_mode = cJSON_IsString(item) && strcmp(item->valuestring, "AUTO") == 0 ? FLORA_MODE_AUTO : FLORA_MODE_MANUAL;
    item = cJSON_GetObjectItem(root, "action");
    command.action_valid = cJSON_IsString(item) &&
        (strcmp(item->valuestring, "start") == 0 || strcmp(item->valuestring, "stop") == 0);
    command.start = cJSON_IsString(item) && strcmp(item->valuestring, "start") == 0;
    command.retained_delivery = retained;

    flora_sensor_reading_t empty_reading = {0};
    flora_safety_decision_t decision = safety_controller_validate_command(&command, device_config_id(),
                                                                         device_time_unix_ms(), &empty_reading);
    if (decision.allowed) {
        safety_controller_note_command_id(command.command_id);
        if (!command.start || pump_controller_request_start(command.duration_seconds)) {
            if (!command.start) pump_controller_request_stop("remote_stop");
            flora_mqtt_publish_command_ack(command.command_id, "STARTED", "NONE");
        } else {
            flora_mqtt_publish_command_ack(command.command_id, "FAILED", "DRIVER_REJECTED");
        }
    } else {
        flora_mqtt_publish_command_ack(command.command_id, "REJECTED", flora_reject_reason_name(decision.reason));
    }
    cJSON_Delete(root);
}

static void mqtt_event_handler(void *args, esp_event_base_t base, int32_t id, void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;
    switch ((esp_mqtt_event_id_t)id) {
    case MQTT_EVENT_CONNECTED:
        s_connected = true;
        {
            char command_topic[FLORA_MQTT_TOPIC_MAX];
            topic_for(command_topic, sizeof(command_topic), "command");
            esp_mqtt_client_subscribe(s_client, command_topic, 1);
            topic_for(command_topic, sizeof(command_topic), "task");
            esp_mqtt_client_subscribe(s_client, command_topic, 1);
        }
        break;
    case MQTT_EVENT_DISCONNECTED:
        s_connected = false;
        break;
    case MQTT_EVENT_DATA:
        if (event->topic && strstr(event->topic, "/command")) {
            handle_command_json(event->data, event->data_len, event->retain);
        } else if (event->topic && strstr(event->topic, "/task")) {
            cJSON *task = cJSON_ParseWithLength(event->data, event->data_len);
            cJSON *action = task ? cJSON_GetObjectItem(task, "action") : NULL;
            if (cJSON_IsString(action) && strcmp(action->valuestring, "reboot") == 0) {
                cJSON_Delete(task);
                esp_restart();
            }
            cJSON_Delete(task);
        }
        break;
    default:
        break;
    }
}

void flora_mqtt_client_init(void)
{
    esp_mqtt_client_config_t config = {
        .broker.address.uri = device_config_mqtt_uri(),
        .credentials.username = device_config_mqtt_username(),
        .credentials.authentication.password = device_config_mqtt_password(),
        .session.last_will = {
            .topic = NULL,
            .retain = false,
        },
    };
    s_client = esp_mqtt_client_init(&config);
    ESP_ERROR_CHECK(esp_mqtt_client_register_event(s_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL));
    ESP_ERROR_CHECK(esp_mqtt_client_start(s_client));
}

bool flora_mqtt_client_connected(void)
{
    return s_connected;
}

void flora_mqtt_publish_telemetry(const flora_sensor_reading_t *reading)
{
    if (!reading || !s_connected) return;
    cJSON *root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "schema_version", FLORA_SCHEMA_VERSION);
    cJSON_AddStringToObject(root, "device_id", device_config_id());
    cJSON_AddStringToObject(root, "plant_id", device_config_plant_id());
    char sampled_at[32];
    if (device_time_iso_now(sampled_at, sizeof(sampled_at))) {
        cJSON_AddStringToObject(root, "sampled_at", sampled_at);
    } else {
        cJSON_AddNullToObject(root, "sampled_at");
    }
    cJSON *metrics = cJSON_AddObjectToObject(root, "metrics");
    cJSON_AddNumberToObject(metrics, "soil_moisture_percent", reading->soil_moisture_percent);
    cJSON_AddNumberToObject(metrics, "air_temperature_c", reading->air_temperature_c);
    cJSON_AddNumberToObject(metrics, "air_humidity_percent", reading->air_humidity_percent);
    cJSON_AddNumberToObject(metrics, "leaf_temperature_c", reading->leaf_temperature_c);
    publish_json("telemetry", root, 1, false);
    cJSON_Delete(root);
}

void flora_mqtt_publish_status(const flora_device_status_t *status)
{
    if (!status || !s_connected) return;
    cJSON *root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "schema_version", FLORA_SCHEMA_VERSION);
    cJSON_AddStringToObject(root, "device_id", device_config_id());
    char reported_at[32] = "1970-01-01T00:00:00Z";
    device_time_iso_now(reported_at, sizeof(reported_at));
    cJSON_AddStringToObject(root, "reported_at", reported_at);
    cJSON_AddStringToObject(root, "mode", flora_mode_name(status->mode));
    cJSON *pump = cJSON_AddObjectToObject(root, "pump");
    cJSON_AddStringToObject(pump, "state", status->pump_state == FLORA_PUMP_RUNNING ? "running" : "off");
    cJSON_AddNumberToObject(pump, "run_remaining_seconds", status->pump_remaining_seconds);
    cJSON *network = cJSON_AddObjectToObject(root, "network");
    cJSON_AddBoolToObject(network, "wifi_connected", status->wifi_connected);
    cJSON_AddBoolToObject(network, "mqtt_connected", status->mqtt_connected);
    cJSON_AddStringToObject(root, "firmware_version", status->firmware_version);
    publish_json("status", root, 1, true);
    cJSON_Delete(root);
}

void flora_mqtt_publish_command_ack(const char *command_id, const char *status, const char *reason)
{
    if (!s_connected) return;
    cJSON *root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "schema_version", FLORA_SCHEMA_VERSION);
    cJSON_AddStringToObject(root, "command_id", command_id ? command_id : "unknown");
    cJSON_AddStringToObject(root, "device_id", device_config_id());
    cJSON_AddStringToObject(root, "status", status);
    cJSON_AddStringToObject(root, "reason_code", reason ? reason : "NONE");
    char ack_at[32] = "1970-01-01T00:00:00Z";
    device_time_iso_now(ack_at, sizeof(ack_at));
    cJSON_AddStringToObject(root, "ack_at", ack_at);
    publish_json("command_ack", root, 1, false);
    cJSON_Delete(root);
}
