#include "router.h"

#include "../authentication/auth.h"
#include "../core/sim_store.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static bool json_number(const char *body, const char *key, double *out)
{
    char pattern[96];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *pos = body ? strstr(body, pattern) : NULL;
    if (!pos) return false;
    pos = strchr(pos + strlen(pattern), ':');
    if (!pos) return false;
    char *end = NULL;
    double value = strtod(pos + 1, &end);
    if (end == pos + 1) return false;
    *out = value;
    return true;
}

static bool json_string(const char *body, const char *key, char *out, size_t out_size)
{
    char pattern[96];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *pos = body ? strstr(body, pattern) : NULL;
    if (!pos) return false;
    pos = strchr(pos + strlen(pattern), ':');
    if (!pos) return false;
    ++pos;
    while (*pos == ' ' || *pos == '\t') ++pos;
    if (*pos != '"') return false;
    ++pos;
    size_t len = 0;
    while (pos[len] && pos[len] != '"' && len + 1 < out_size) {
        out[len] = pos[len];
        ++len;
    }
    out[len] = '\0';
    return pos[len] == '"';
}

static bool json_bool(const char *body, const char *key, bool *out)
{
    char pattern[96];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *pos = body ? strstr(body, pattern) : NULL;
    if (!pos) return false;
    pos = strchr(pos + strlen(pattern), ':');
    if (!pos) return false;
    ++pos;
    while (*pos == ' ' || *pos == '\t') ++pos;
    if (strncmp(pos, "true", 4) == 0) {
        *out = true;
        return true;
    }
    if (strncmp(pos, "false", 5) == 0) {
        *out = false;
        return true;
    }
    return false;
}

static char *json_long_string(const char *body, const char *key);
static bool store_base64_image(const char *encoded, const char *filename,
                               char *image_path, size_t image_path_size);
static void remove_plant_uploaded_files(const char *plant_id);

static bool path_device_id(const char *path, char *device_id, size_t size)
{
    const char *prefix = "/v1/devices/";
    if (!path || strncmp(path, prefix, strlen(prefix)) != 0) return false;
    const char *start = path + strlen(prefix);
    const char *end = strchr(start, '/');
    size_t len = end ? (size_t)(end - start) : strlen(start);
    if (len == 0 || len >= size) return false;
    memcpy(device_id, start, len);
    device_id[len] = '\0';
    return true;
}

static bool path_plant_id(const char *path, char *plant_id, size_t size)
{
    const char *prefix = "/v1/plants/";
    if (!path || strncmp(path, prefix, strlen(prefix)) != 0) return false;
    const char *start = path + strlen(prefix);
    if (strchr(start, '/')) return false;
    size_t len = strlen(start);
    if (len == 0 || len >= size) return false;
    memcpy(plant_id, start, len);
    plant_id[len] = '\0';
    return true;
}

static bool path_image_id(const char *path, char *image_id, size_t size)
{
    const char *prefix = "/v1/images/";
    if (!path || strncmp(path, prefix, strlen(prefix)) != 0) return false;
    const char *start = path + strlen(prefix);
    if (strchr(start, '/')) return false;
    size_t len = strlen(start);
    if (len == 0 || len >= size) return false;
    memcpy(image_id, start, len);
    image_id[len] = '\0';
    return true;
}

static int handle_sim_telemetry(const char *path, const char *body, char *response, size_t response_size)
{
    const sim_state_t *state = sim_store_state();
    sim_reading_t reading = {0};
    reading.sampled_at_unix_ms = sim_now_ms();
    path_device_id(path, reading.device_id, sizeof(reading.device_id));
    json_string(body, "device_id", reading.device_id, sizeof(reading.device_id));
    if (!reading.device_id[0]) {
        snprintf(reading.device_id, sizeof(reading.device_id), "%s", state->device_id);
    }
    json_string(body, "plant_id", reading.plant_id, sizeof(reading.plant_id));
    if (!reading.plant_id[0]) {
        for (size_t i = 0; i < state->plant_count; ++i) {
            if (strcmp(state->plants[i].device_id, reading.device_id) == 0) {
                snprintf(reading.plant_id, sizeof(reading.plant_id), "%s", state->plants[i].id);
                break;
            }
        }
    }
    if (!reading.plant_id[0]) {
        snprintf(reading.plant_id, sizeof(reading.plant_id), "%s", state->plant_id);
    }
    if (!reading.device_id[0] || strcmp(reading.device_id, state->device_id) != 0) {
        snprintf(response, response_size, "{\"status\":\"rejected\",\"reason\":\"UNREGISTERED_DEVICE\"}");
        return 422;
    }
    bool plant_bound = false;
    for (size_t i = 0; i < state->plant_count; ++i) {
        if (strcmp(state->plants[i].id, reading.plant_id) == 0 &&
            strcmp(state->plants[i].device_id, reading.device_id) == 0) {
            plant_bound = true;
            break;
        }
    }
    if (!plant_bound) {
        snprintf(response, response_size, "{\"status\":\"rejected\",\"reason\":\"PLANT_DEVICE_MISMATCH\"}");
        return 422;
    }
    double value = 0;
    reading.soil_valid = json_number(body, "soil_moisture_percent", &value);
    reading.soil_moisture = value;
    reading.air_valid = json_number(body, "air_temperature_c", &value);
    reading.air_temperature = value;
    if (json_number(body, "air_humidity_percent", &value)) reading.air_humidity = value;
    reading.leaf_valid = json_number(body, "leaf_temperature_c", &value);
    reading.leaf_temperature = value;
    sim_store_add_reading(&reading);
    snprintf(response, response_size, "{\"status\":\"accepted\",\"plantId\":\"%s\"}", reading.plant_id);
    return 202;
}

static int handle_ai_result(const char *body, char *response, size_t response_size)
{
    char plant_id[FLORA_ID_MAX] = "";
    char level[16] = "LOW";
    char recommendation[512] = "";
    char model_version[64] = "flora-rules-v1";
    double score = 0;
    double exg = 0;
    double green_ratio = 0;
    double leaf_air_delta = 0;
    double moisture_trend = 0;
    json_string(body, "plant_id", plant_id, sizeof(plant_id));
    json_string(body, "plantId", plant_id, sizeof(plant_id));
    json_string(body, "risk_level", level, sizeof(level));
    json_number(body, "risk_score", &score);
    json_string(body, "recommendation", recommendation, sizeof(recommendation));
    json_string(body, "model_version", model_version, sizeof(model_version));
    bool has_exg = json_number(body, "exg", &exg);
    bool has_green = json_number(body, "green_ratio", &green_ratio);
    json_number(body, "leaf_air_delta_c", &leaf_air_delta);
    json_number(body, "moisture_trend_per_hour", &moisture_trend);
    sim_store_set_ai_result(plant_id, level, (int)score, recommendation, model_version,
                            exg, green_ratio, leaf_air_delta, moisture_trend,
                            has_exg && has_green);
    snprintf(response, response_size, "{\"status\":\"accepted\"}");
    return 202;
}

static int handle_pump_status(const char *body, char *response, size_t response_size)
{
    char state[16] = "off";
    char device_id[FLORA_ID_MAX] = "";
    char name[64] = "";
    char firmware_version[24] = "";
    char ip[40] = "";
    double remaining = 0;
    double battery_percent = -1;
    json_string(body, "state", state, sizeof(state));
    json_string(body, "device_id", device_id, sizeof(device_id));
    json_string(body, "name", name, sizeof(name));
    json_string(body, "firmware_version", firmware_version, sizeof(firmware_version));
    json_string(body, "ip", ip, sizeof(ip));
    json_number(body, "run_remaining_seconds", &remaining);
    json_number(body, "battery_percent", &battery_percent);
    const sim_state_t *current = sim_store_state();
    if (!device_id[0]) snprintf(device_id, sizeof(device_id), "%s", current->device_id);
    if (!device_id[0] || strcmp(device_id, current->device_id) != 0) {
        snprintf(response, response_size, "{\"status\":\"rejected\",\"reason\":\"UNREGISTERED_DEVICE\"}");
        return 422;
    }
    sim_store_update_device_status(device_id, name, firmware_version, ip, (int)battery_percent);
    sim_store_update_pump_status(state, (uint32_t)remaining);
    snprintf(response, response_size, "{\"status\":\"accepted\"}");
    return 202;
}

static int handle_command_ack(const char *body, char *response, size_t response_size)
{
    char command_id[FLORA_ID_MAX] = "";
    char status[32] = "UNKNOWN";
    char reason[FLORA_REASON_MAX] = "NONE";
    json_string(body, "command_id", command_id, sizeof(command_id));
    json_string(body, "status", status, sizeof(status));
    json_string(body, "reason_code", reason, sizeof(reason));
    sim_store_record_command_ack(command_id, status, reason);
    snprintf(response, response_size, "{\"status\":\"accepted\"}");
    return 202;
}

static int handle_image_analysis(const char *body, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    char status[24] = "ANALYZED";
    double exg = 0;
    double green_ratio = 0;
    bool quality_ok = strcmp(status, "ANALYZED") == 0;
    json_string(body, "id", id, sizeof(id));
    json_string(body, "status", status, sizeof(status));
    json_number(body, "exg", &exg);
    json_number(body, "green_ratio", &green_ratio);
    json_bool(body, "quality_ok", &quality_ok);
    json_bool(body, "qualityOk", &quality_ok);
    if (!sim_store_update_image_metrics(id, status, exg, green_ratio, quality_ok)) {
        snprintf(response, response_size, "{\"error\":\"image_not_found\"}");
        return 404;
    }
    snprintf(response, response_size, "{\"status\":\"saved\"}");
    return 200;
}

static int handle_add_plant(const char *body, char *response, size_t response_size)
{
    char name[96] = "";
    char zone[64] = "";
    char device_id[FLORA_ID_MAX] = "";
    char image[128] = "";
    char image_path[256] = "";
    char filename[128] = "";
    char status[16] = "LOW";
    double moisture = 0;
    char id[FLORA_ID_MAX] = "";
    json_string(body, "name", name, sizeof(name));
    json_string(body, "zone", zone, sizeof(zone));
    json_string(body, "deviceId", device_id, sizeof(device_id));
    json_string(body, "imageAsset", image, sizeof(image));
    json_string(body, "imagePath", image_path, sizeof(image_path));
    json_string(body, "fileName", filename, sizeof(filename));
    json_string(body, "healthStatus", status, sizeof(status));
    json_number(body, "soilMoisture", &moisture);
    if (!device_id[0]) snprintf(device_id, sizeof(device_id), "%s", sim_store_state()->device_id);

    char *encoded = json_long_string(body, "imageBase64");
    if (encoded) {
        bool stored = store_base64_image(encoded, filename, image_path, sizeof(image_path));
        free(encoded);
        if (!stored) {
            snprintf(response, response_size, "{\"error\":\"invalid_image_upload\"}");
            return 400;
        }
    }
    int sensor_channel = sim_store_available_sensor_channel(device_id);
    if (sensor_channel < 0) {
        snprintf(response, response_size, "{\"error\":\"HARDWARE_CHANNELS_FULL\",\"maxChannels\":%d}",
                 SIM_MAX_DEVICE_CHANNELS);
        return 422;
    }
    if (!sim_store_add_plant(name, zone, device_id, image, image_path,
                           status, moisture, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_plant\"}");
        return 400;
    }
    if (image_path[0]) {
        char image_id[FLORA_ID_MAX] = "";
        sim_store_add_image(id, image_path, "UPLOADED", 0, 0, image_id, sizeof(image_id));
    }
    snprintf(response, response_size,
             "{\"status\":\"created\",\"id\":\"%s\",\"imagePath\":\"%s\",\"sensorChannel\":%d}",
             id, image_path, sensor_channel);
    return 201;
}

static int handle_update_plant(const char *path, const char *body, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    char name[96] = "";
    char zone[64] = "";
    char device_id[FLORA_ID_MAX] = "";
    char image_path[256] = "";
    char filename[128] = "";
    char status[16] = "LOW";
    int sensor_channel = -1;
    if (!path_plant_id(path, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_plant_path\"}");
        return 400;
    }
    json_string(body, "name", name, sizeof(name));
    json_string(body, "zone", zone, sizeof(zone));
    json_string(body, "deviceId", device_id, sizeof(device_id));
    json_string(body, "fileName", filename, sizeof(filename));
    json_string(body, "healthStatus", status, sizeof(status));

    char *encoded = json_long_string(body, "imageBase64");
    if (encoded) {
        bool stored = store_base64_image(encoded, filename, image_path, sizeof(image_path));
        free(encoded);
        if (!stored) {
            snprintf(response, response_size, "{\"error\":\"invalid_image_upload\"}");
            return 400;
        }
    }
    if (!sim_store_update_plant(id, name, zone, device_id, image_path, status,
                                &sensor_channel)) {
        snprintf(response, response_size, "{\"error\":\"plant_not_found_or_invalid\"}");
        return 404;
    }
    if (image_path[0]) {
        char image_id[FLORA_ID_MAX] = "";
        sim_store_add_image(id, image_path, "UPLOADED", 0, 0, image_id, sizeof(image_id));
    }
    snprintf(response, response_size,
             "{\"status\":\"updated\",\"id\":\"%s\",\"imagePath\":\"%s\",\"sensorChannel\":%d}",
             id, image_path, sensor_channel);
    return 200;
}

static int handle_delete_plant(const char *path, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    if (!path_plant_id(path, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_plant_path\"}");
        return 400;
    }
    remove_plant_uploaded_files(id);
    if (!sim_store_delete_plant(id)) {
        snprintf(response, response_size, "{\"error\":\"plant_not_found\"}");
        return 404;
    }
    snprintf(response, response_size, "{\"status\":\"deleted\",\"id\":\"%s\"}", id);
    return 200;
}

static int handle_add_image(const char *body, char *response, size_t response_size)
{
    char plant_id[FLORA_ID_MAX] = "";
    char image_path[192] = "";
    char status[24] = "PENDING";
    char id[FLORA_ID_MAX] = "";
    double exg = 0;
    double green_ratio = 0;
    json_string(body, "plantId", plant_id, sizeof(plant_id));
    json_string(body, "imagePath", image_path, sizeof(image_path));
    json_string(body, "status", status, sizeof(status));
    json_number(body, "exg", &exg);
    json_number(body, "greenRatio", &green_ratio);
    if (!sim_store_add_image(plant_id, image_path, status, exg, green_ratio, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_image\"}");
        return 400;
    }
    snprintf(response, response_size, "{\"status\":\"created\",\"id\":\"%s\"}", id);
    return 201;
}

static int handle_ack_alert(const char *body, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    json_string(body, "id", id, sizeof(id));
    if (!sim_store_acknowledge_alert(id)) {
        snprintf(response, response_size, "{\"error\":\"alert_not_found\"}");
        return 404;
    }
    snprintf(response, response_size, "{\"status\":\"acknowledged\"}");
    return 200;
}

static int handle_settings_update(const char *body, char *response, size_t response_size)
{
    char error[96] = "";
    if (!sim_store_update_settings(body, error, sizeof(error))) {
        snprintf(response, response_size, "{\"error\":\"%s\"}", error);
        return 400;
    }
    snprintf(response, response_size, "{\"status\":\"saved\"}");
    return 200;
}

static int handle_create_device(const char *body, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    char name[96] = "";
    char error[96] = "";
    json_string(body, "id", id, sizeof(id));
    json_string(body, "deviceId", id, sizeof(id));
    json_string(body, "name", name, sizeof(name));
    if (!sim_store_register_device(id, name, error, sizeof(error))) {
        snprintf(response, response_size, "{\"error\":\"%s\"}", error);
        return strcmp(error, "DEVICE_ALREADY_REGISTERED") == 0 ? 422 : 400;
    }
    snprintf(response, response_size, "{\"status\":\"created\",\"id\":\"%s\"}", id);
    return 201;
}

static int handle_update_device(const char *path, const char *body, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    char new_id[FLORA_ID_MAX] = "";
    char name[96] = "";
    char error[96] = "";
    if (!path_device_id(path, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_device_path\"}");
        return 400;
    }
    json_string(body, "newId", new_id, sizeof(new_id));
    json_string(body, "newDeviceId", new_id, sizeof(new_id));
    json_string(body, "name", name, sizeof(name));
    if (!sim_store_update_device(id, new_id, name, error, sizeof(error))) {
        snprintf(response, response_size, "{\"error\":\"%s\"}", error);
        return strcmp(error, "DEVICE_NOT_FOUND") == 0 ? 404 : 422;
    }
    snprintf(response, response_size, "{\"status\":\"updated\",\"id\":\"%s\"}", new_id[0] ? new_id : id);
    return 200;
}

static int handle_delete_device(const char *path, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    char error[96] = "";
    if (!path_device_id(path, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_device_path\"}");
        return 400;
    }
    if (!sim_store_delete_device(id, error, sizeof(error))) {
        snprintf(response, response_size, "{\"error\":\"%s\"}", error);
        return strcmp(error, "DEVICE_NOT_FOUND") == 0 ? 404 : 422;
    }
    snprintf(response, response_size, "{\"status\":\"deleted\",\"id\":\"%s\"}", id);
    return 200;
}

static int handle_reboot_request(const char *path, char *response, size_t response_size)
{
    char device_id[FLORA_ID_MAX];
    const sim_state_t *state = sim_store_state();
    if (!path_device_id(path, device_id, sizeof(device_id)) || strcmp(device_id, state->device_id) != 0) {
        snprintf(response, response_size, "{\"status\":\"rejected\",\"reason\":\"UNKNOWN_DEVICE\"}");
        return 422;
    }
    bool online = state->last_seen_unix_ms > 0 && sim_now_ms() - state->last_seen_unix_ms <= 30000;
    if (!online) {
        snprintf(response, response_size, "{\"status\":\"rejected\",\"reason\":\"DEVICE_OFFLINE\"}");
        return 422;
    }
    sim_store_request_reboot();
    snprintf(response, response_size, "{\"status\":\"queued\",\"deviceId\":\"%s\"}", device_id);
    return 202;
}

static int handle_mode_update(const char *body, char *response, size_t response_size)
{
    char mode[16] = "";
    char error[96] = "";
    json_string(body, "mode", mode, sizeof(mode));
    if (!sim_store_set_mode(mode, error, sizeof(error))) {
        snprintf(response, response_size, "{\"error\":\"%s\"}", error);
        return 400;
    }
    snprintf(response, response_size, "{\"status\":\"saved\",\"mode\":\"%s\"}", mode);
    return 200;
}

static int base64_value(unsigned char c)
{
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}

static unsigned char *base64_decode(const char *input, size_t *out_size)
{
    size_t len = input ? strlen(input) : 0;
    unsigned char *out = malloc((len / 4 + 1) * 3 + 1);
    if (!out) return NULL;
    size_t used = 0;
    for (size_t i = 0; i + 3 < len; i += 4) {
        int a = base64_value((unsigned char)input[i]);
        int b = base64_value((unsigned char)input[i + 1]);
        int c = input[i + 2] == '=' ? -2 : base64_value((unsigned char)input[i + 2]);
        int d = input[i + 3] == '=' ? -2 : base64_value((unsigned char)input[i + 3]);
        if (a < 0 || b < 0 || c == -1 || d == -1) { free(out); return NULL; }
        unsigned int value = ((unsigned int)a << 18) | ((unsigned int)b << 12) |
                             ((unsigned int)(c < 0 ? 0 : c) << 6) | (unsigned int)(d < 0 ? 0 : d);
        out[used++] = (unsigned char)(value >> 16);
        if (c >= 0) out[used++] = (unsigned char)(value >> 8);
        if (d >= 0) out[used++] = (unsigned char)value;
    }
    *out_size = used;
    return out;
}

static char *json_long_string(const char *body, const char *key)
{
    char pattern[96];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *pos = body ? strstr(body, pattern) : NULL;
    if (!pos) return NULL;
    pos = strchr(pos + strlen(pattern), ':');
    if (!pos) return NULL;
    ++pos;
    while (*pos == ' ' || *pos == '\t') ++pos;
    if (*pos != '"') return NULL;
    ++pos;
    const char *end = strchr(pos, '"');
    if (!end) return NULL;
    size_t len = (size_t)(end - pos);
    char *value = malloc(len + 1);
    if (!value) return NULL;
    memcpy(value, pos, len);
    value[len] = '\0';
    return value;
}

static bool safe_filename(const char *name)
{
    if (!name || !name[0] || strlen(name) > 120 || strstr(name, "..") || strchr(name, '/') || strchr(name, '\\')) return false;
    return true;
}

static const char *upload_dir(void)
{
    const char *dir = getenv("FLORA_UPLOAD_DIR");
    return (dir && dir[0]) ? dir : "data/uploads";
}

static bool image_path_for_id(const char *id, char *path, size_t size)
{
    const sim_state_t *state = sim_store_state();
    for (size_t i = 0; i < state->image_count; ++i) {
        size_t index = (state->image_next + SIM_MAX_IMAGES - state->image_count + i) % SIM_MAX_IMAGES;
        if (strcmp(state->images[index].id, id) == 0) {
            snprintf(path, size, "%s", state->images[index].image_path);
            return true;
        }
    }
    return false;
}

static void remove_uploaded_file(const char *image_path)
{
    if (!image_path || strncmp(image_path, "/uploads/", strlen("/uploads/")) != 0) return;
    const char *filename = image_path + strlen("/uploads/");
    if (!safe_filename(filename)) return;
    char disk_path[512];
    snprintf(disk_path, sizeof(disk_path), "%s/%s", upload_dir(), filename);
    remove(disk_path);
}

static void remove_plant_uploaded_files(const char *plant_id)
{
    const sim_state_t *state = sim_store_state();
    for (size_t i = 0; i < state->image_count; ++i) {
        size_t index = (state->image_next + SIM_MAX_IMAGES - state->image_count + i) % SIM_MAX_IMAGES;
        if (strcmp(state->images[index].plant_id, plant_id) == 0) {
            remove_uploaded_file(state->images[index].image_path);
        }
    }
}

static bool store_base64_image(const char *encoded, const char *filename,
                               char *image_path, size_t image_path_size)
{
    if (!encoded || !safe_filename(filename)) return false;
    size_t data_size = 0;
    unsigned char *data = base64_decode(encoded, &data_size);
    if (!data || data_size == 0) {
        free(data);
        return false;
    }
    mkdir(upload_dir(), 0755);
    char disk_path[512];
    snprintf(disk_path, sizeof(disk_path), "%s/%s", upload_dir(), filename);
    FILE *file = fopen(disk_path, "wb");
    if (!file) {
        free(data);
        return false;
    }
    fwrite(data, 1, data_size, file);
    fclose(file);
    free(data);
    snprintf(image_path, image_path_size, "/uploads/%s", filename);
    return true;
}

static int handle_upload_image(const char *body, char *response, size_t response_size)
{
    char plant_id[FLORA_ID_MAX] = "";
    char filename[128] = "";
    char status[24] = "UPLOADED";
    char *encoded = json_long_string(body, "dataBase64");
    json_string(body, "plantId", plant_id, sizeof(plant_id));
    json_string(body, "fileName", filename, sizeof(filename));
    if (!encoded || !plant_id[0] || !safe_filename(filename)) {
        free(encoded);
        snprintf(response, response_size, "{\"error\":\"invalid_upload\"}");
        return 400;
    }
    char image_path[256];
    bool stored = store_base64_image(encoded, filename, image_path, sizeof(image_path));
    free(encoded);
    if (!stored) {
        snprintf(response, response_size, "{\"error\":\"invalid_base64\"}");
        return 400;
    }
    char id[FLORA_ID_MAX] = "";
    if (!sim_store_add_image(plant_id, image_path, status, 0, 0, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_image\"}");
        return 400;
    }
    snprintf(response, response_size, "{\"status\":\"created\",\"id\":\"%s\",\"imagePath\":\"%s\"}", id, image_path);
    return 201;
}

static int handle_update_image(const char *path, const char *body, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    char plant_id[FLORA_ID_MAX] = "";
    char filename[128] = "";
    char image_path[256] = "";
    char old_path[256] = "";
    if (!path_image_id(path, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_image_path\"}");
        return 400;
    }
    json_string(body, "plantId", plant_id, sizeof(plant_id));
    json_string(body, "fileName", filename, sizeof(filename));
    image_path_for_id(id, old_path, sizeof(old_path));

    char *encoded = json_long_string(body, "imageBase64");
    if (encoded) {
        bool stored = store_base64_image(encoded, filename, image_path, sizeof(image_path));
        free(encoded);
        if (!stored) {
            snprintf(response, response_size, "{\"error\":\"invalid_image_upload\"}");
            return 400;
        }
    }
    if (!sim_store_update_image(id, plant_id, image_path)) {
        snprintf(response, response_size, "{\"error\":\"image_not_found_or_invalid\"}");
        return 404;
    }
    if (image_path[0] && strcmp(old_path, image_path) != 0) remove_uploaded_file(old_path);
    snprintf(response, response_size,
             "{\"status\":\"updated\",\"id\":\"%s\",\"imagePath\":\"%s\"}",
             id, image_path[0] ? image_path : old_path);
    return 200;
}

static int handle_delete_image(const char *path, char *response, size_t response_size)
{
    char id[FLORA_ID_MAX] = "";
    char image_path[256] = "";
    if (!path_image_id(path, id, sizeof(id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_image_path\"}");
        return 400;
    }
    image_path_for_id(id, image_path, sizeof(image_path));
    if (!sim_store_delete_image(id)) {
        snprintf(response, response_size, "{\"error\":\"image_not_found\"}");
        return 404;
    }
    remove_uploaded_file(image_path);
    snprintf(response, response_size, "{\"status\":\"deleted\",\"id\":\"%s\"}", id);
    return 200;
}

static int handle_command(const char *path, const char *body, char *response, size_t response_size)
{
    char device_id[FLORA_ID_MAX];
    if (!path_device_id(path, device_id, sizeof(device_id))) {
        snprintf(response, response_size, "{\"error\":\"invalid_device_path\"}");
        return 400;
    }
    const sim_state_t *state = sim_store_state();
    bool device_online = strcmp(device_id, state->device_id) == 0 &&
                         state->last_seen_unix_ms > 0 &&
                         sim_now_ms() - state->last_seen_unix_ms <= 30000;
    if (!device_online) {
        snprintf(response, response_size, "{\"status\":\"rejected\",\"reason\":\"DEVICE_OFFLINE\"}");
        return 422;
    }
    char requested_plant_id[FLORA_ID_MAX] = "";
    json_string(body, "plant_id", requested_plant_id, sizeof(requested_plant_id));
    json_string(body, "plantId", requested_plant_id, sizeof(requested_plant_id));
    const sim_plant_t *plant = NULL;
    for (size_t i = 0; i < state->plant_count; ++i) {
        bool plant_matches = !requested_plant_id[0] || strcmp(state->plants[i].id, requested_plant_id) == 0;
        if (plant_matches && strcmp(state->plants[i].device_id, device_id) == 0) {
            plant = &state->plants[i];
            break;
        }
    }
    if (!plant) {
        snprintf(response, response_size, "{\"status\":\"rejected\",\"reason\":\"PLANT_DEVICE_MISMATCH\"}");
        return 422;
    }
    char action[16] = "start";
    double duration = 30;
    json_string(body, "action", action, sizeof(action));
    json_number(body, "duration_seconds", &duration);
    char reason[FLORA_REASON_MAX] = {0};
    bool accepted = sim_store_submit_command(device_id, plant->id,
                                           action, (uint32_t)duration, reason, sizeof(reason));
    snprintf(response, response_size, "{\"status\":\"%s\",\"reason\":\"%s\",\"plantId\":\"%s\"}",
             accepted ? "accepted" : "rejected", reason, plant->id);
    return accepted ? 202 : 422;
}

static int handle_session(const char *authorization, char *response, size_t response_size)
{
    const char *required = getenv("FLORA_API_TOKEN");
    const char *operator_name = getenv("FLORA_OPERATOR_NAME");
    const char *operator_role = getenv("FLORA_OPERATOR_ROLE");
    const char *system_user = getenv("USER");
    const char *name = operator_name && operator_name[0] ? operator_name :
                       (system_user && system_user[0] ? system_user : "local-operator");
    const char *role = operator_role && operator_role[0] ? operator_role : "local-operator";
    flora_auth_subject_t subject = {0};
    bool authenticated = required && required[0] && authorization &&
                         strncmp(authorization, "Bearer ", 7) == 0 &&
                         auth_verify_bearer(authorization + 7, &subject);
    const char *expected_id = sim_store_expected_device_id();
    const char *expected_name = getenv("FLORA_DEVICE_NAME");
    if (!expected_name || !expected_name[0]) expected_name = sim_store_state()->device_name;
    if (!expected_name || !expected_name[0]) expected_name = expected_id;
    snprintf(response, response_size,
             "{\"name\":\"%s\",\"role\":\"%s\",\"authenticated\":%s,\"authMode\":\"%s\",\"apiVersion\":\"v1\",\"expectedDeviceId\":\"%s\",\"expectedDeviceName\":\"%s\"}",
             name, role, authenticated ? "true" : "false",
             required && required[0] ? "bearer" : "none",
             expected_id, expected_name);
    return 200;
}

static bool is_device_path(const char *path)
{
    return path && (strncmp(path, "/v1/sim/", strlen("/v1/sim/")) == 0 ||
                    strstr(path, "/telemetry") || strstr(path, "/pump-status") ||
                    strstr(path, "/commands/pending") || strstr(path, "/tasks/pending") ||
                    strstr(path, "/command-ack"));
}

static bool authorized(const char *path, const char *authorization)
{
    const char *required = is_device_path(path) ? getenv("FLORA_DEVICE_TOKEN") : getenv("FLORA_API_TOKEN");
    if (!required || !required[0]) return true;
    if (!authorization || strncmp(authorization, "Bearer ", 7) != 0) return false;
    return strcmp(authorization + 7, required) == 0;
}

int api_route_request(const char *method, const char *path, const char *body,
                      const char *authorization, char *response, size_t response_size)
{
    if (!method || !path || !response || response_size == 0) return 500;
    response[0] = '\0';
    const sim_state_t *state = sim_store_state();
    if (!state->device_id[0]) sim_store_init();

    if (strcmp(method, "GET") == 0 && strcmp(path, "/healthz") == 0) {
        snprintf(response, response_size, "{\"status\":\"ok\"}");
        return 200;
    }
    if (!authorized(path, authorization)) {
        snprintf(response, response_size, "{\"error\":\"unauthenticated\"}");
        return 401;
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/session") == 0) {
        return handle_session(authorization, response, response_size);
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/healthz") == 0) {
        snprintf(response, response_size, "{\"status\":\"ok\"}");
        return 200;
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/dashboard") == 0) {
        sim_store_dashboard_json(response, response_size);
        return 200;
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/readings") == 0) {
        sim_store_readings_json(response, response_size);
        return 200;
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/plants") == 0) {
        sim_store_plants_json(response, response_size);
        return 200;
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/alerts") == 0) {
        sim_store_alerts_json(response, response_size);
        return 200;
    }

    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/images") == 0) {
        sim_store_images_json(response, response_size);
        return 200;
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/images") == 0) {
        return handle_add_image(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/images/upload") == 0) {
        return handle_upload_image(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/images/analysis") == 0) {
        return handle_image_analysis(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strncmp(path, "/v1/images/", strlen("/v1/images/")) == 0) {
        return handle_update_image(path, body, response, response_size);
    }
    if (strcmp(method, "DELETE") == 0 && strncmp(path, "/v1/images/", strlen("/v1/images/")) == 0) {
        return handle_delete_image(path, response, response_size);
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/devices") == 0) {
        sim_store_devices_json(response, response_size);
        return 200;
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/devices") == 0) {
        return handle_create_device(body, response, response_size);
    }
    bool single_device_path = strncmp(path, "/v1/devices/", strlen("/v1/devices/")) == 0 &&
                              strchr(path + strlen("/v1/devices/"), '/') == NULL;
    if (strcmp(method, "POST") == 0 && single_device_path) {
        return handle_update_device(path, body, response, response_size);
    }
    if (strcmp(method, "DELETE") == 0 && single_device_path) {
        return handle_delete_device(path, response, response_size);
    }
    if (strcmp(method, "GET") == 0 && strcmp(path, "/v1/settings") == 0) {
        sim_store_settings_json(response, response_size);
        return 200;
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/settings") == 0) {
        return handle_settings_update(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/mode") == 0) {
        return handle_mode_update(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strstr(path, "/reboot") != NULL) {
        return handle_reboot_request(path, response, response_size);
    }
    if (strcmp(method, "GET") == 0 && strstr(path, "/tasks/pending") != NULL) {
        if (sim_store_pop_reboot()) {
            snprintf(response, response_size, "{\"action\":\"reboot\",\"non_retained\":true}");
        } else {
            snprintf(response, response_size, "null");
        }
        return 200;
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/alerts/acknowledge") == 0) {
        return handle_ack_alert(body, response, response_size);
    }
    if (strcmp(method, "GET") == 0 && strncmp(path, "/v1/reports", strlen("/v1/reports")) == 0) {
        const char *range = strstr(path, "range=");
        sim_store_report_json(range ? range + 6 : "7d", response, response_size);
        return 200;
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/plants") == 0) {
        return handle_add_plant(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strncmp(path, "/v1/plants/", strlen("/v1/plants/")) == 0) {
        return handle_update_plant(path, body, response, response_size);
    }
    if (strcmp(method, "DELETE") == 0 && strncmp(path, "/v1/plants/", strlen("/v1/plants/")) == 0) {
        return handle_delete_plant(path, response, response_size);
    }
    if (strcmp(method, "POST") == 0 &&
        (strcmp(path, "/v1/sim/telemetry") == 0 || strstr(path, "/telemetry") != NULL)) {
        return handle_sim_telemetry(path, body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strcmp(path, "/v1/sim/ai-result") == 0) {
        return handle_ai_result(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 && strstr(path, "/command-ack") != NULL) {
        return handle_command_ack(body, response, response_size);
    }
    if (strcmp(method, "POST") == 0 &&
        (strcmp(path, "/v1/sim/pump-status") == 0 || strstr(path, "/pump-status") != NULL)) {
        return handle_pump_status(body, response, response_size);
    }
    if (strcmp(method, "GET") == 0 && strstr(path, "/commands/pending") != NULL) {
        char device_id[FLORA_ID_MAX];
        if (!path_device_id(path, device_id, sizeof(device_id))) {
            snprintf(response, response_size, "{\"error\":\"invalid_device_path\"}");
            return 400;
        }
        sim_store_pending_command_json(device_id, response, response_size);
        return 200;
    }
    if (strcmp(method, "POST") == 0 && strstr(path, "/commands") != NULL) {
        return handle_command(path, body, response, response_size);
    }
    snprintf(response, response_size, "{\"error\":\"not_found\"}");
    return 404;
}
