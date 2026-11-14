#include "sim_store.h"

#include "../device_commands/command_policy.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

static sim_state_t s_state;
static bool s_loaded_from_disk;

int64_t sim_now_ms(void) { return (int64_t)time(NULL) * 1000; }

static const char *state_file_path(void)
{
    const char *path = getenv("FLORA_STATE_FILE");
    return (path && path[0]) ? path : "data/flora-state.tsv";
}

static const char *default_device_id(void)
{
    const char *device_id = getenv("FLORA_DEVICE_ID");
    return (device_id && device_id[0]) ? device_id : "FLORA-ESP32-WOKWI";
}

const char *sim_store_expected_device_id(void)
{
    return default_device_id();
}

static void escape_text(char *dst, size_t size, const char *src)
{
    size_t used = 0;
    while (src && *src && used + 1 < size) {
        if (*src == '\t' || *src == '\n' || *src == '\r' || *src == '\\') {
            if (used + 2 >= size) break;
            dst[used++] = '\\';
            dst[used++] = *src == '\t' ? 't' : *src == '\n' ? 'n' : *src == '\r' ? 'r' : '\\';
        } else {
            dst[used++] = *src;
        }
        ++src;
    }
    dst[used] = '\0';
}

static void unescape_text(char *dst, size_t size, const char *src)
{
    size_t used = 0;
    while (src && *src && used + 1 < size) {
        if (*src == '\\' && src[1]) {
            ++src;
            dst[used++] = *src == 't' ? '\t' : *src == 'n' ? '\n' : *src == 'r' ? '\r' : *src;
        } else {
            dst[used++] = *src;
        }
        ++src;
    }
    dst[used] = '\0';
}

static char *next_field(char **cursor)
{
    if (!cursor || !*cursor) return NULL;
    char *start = *cursor;
    char *tab = strchr(start, '\t');
    char *newline = strchr(start, '\n');
    char *end = tab && (!newline || tab < newline) ? tab : newline;
    if (end) {
        *end = '\0';
        *cursor = end + 1;
    } else {
        *cursor = NULL;
    }
    return start;
}

static void sim_store_save(void)
{
    if (!s_loaded_from_disk) return;
    const char *path = state_file_path();
    const char *slash = strrchr(path, '/');
    if (slash) {
        char dir[256] = {0};
        size_t len = (size_t)(slash - path);
        if (len < sizeof(dir)) {
            memcpy(dir, path, len);
            mkdir(dir, 0755);
        }
    }
    FILE *file = fopen(path, "w");
    if (!file) return;
    char e[1024];
    fprintf(file, "FLORA_STATE\t1\n");
    escape_text(e, sizeof(e), s_state.device_id); fprintf(file, "META\t%s\t", e);
    escape_text(e, sizeof(e), s_state.plant_id); fprintf(file, "%s\t", e);
    escape_text(e, sizeof(e), s_state.firmware_version); fprintf(file, "%s\t", e);
    escape_text(e, sizeof(e), s_state.device_ip); fprintf(file, "%s\t%d\t%s\t%s\t%u\t%s\t%d\t%lld\t",
            e, s_state.battery_percent, flora_mode_name(s_state.mode), s_state.pump_state,
            s_state.pump_remaining_seconds, s_state.risk_level, s_state.risk_score,
            (long long)s_state.last_seen_unix_ms);
    escape_text(e, sizeof(e), s_state.device_name); fprintf(file, "%s\n", e);
    const sim_settings_t *set = &s_state.settings;
    escape_text(e, sizeof(e), set->language); fprintf(file, "SETTINGS\t%d\t%d\t%d\t%d\t%d\t%s\t", set->notify_app, set->notify_email, set->notify_line, set->pump_enabled, set->auto_irrigation, e);
    escape_text(e, sizeof(e), set->display_mode); fprintf(file, "%s\t%.6f\t%.6f\t%u\t%.6f\n", e, set->auto_start_moisture, set->auto_stop_moisture, set->auto_run_seconds, set->high_risk_score);
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        const sim_plant_t *p = &s_state.plants[i];
        fprintf(file, "PLANT\t");
        escape_text(e, sizeof(e), p->id); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), p->name); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), p->zone); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), p->device_id); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), p->image_asset); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), p->image_path); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), p->health_status); fprintf(file, "%s\t%.6f\t%u\t%d\n", e, p->soil_moisture,
                p->sensor_channel, p->soil_valid ? 1 : 0);
    }
    for (size_t i = 0; i < s_state.image_count; ++i) {
        size_t index = (s_state.image_next + SIM_MAX_IMAGES - s_state.image_count + i) % SIM_MAX_IMAGES;
        const sim_image_t *im = &s_state.images[index];
        fprintf(file, "IMAGE\t");
        escape_text(e, sizeof(e), im->id); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), im->plant_id); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), im->image_path); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), im->status); fprintf(file, "%s\t%lld\t%.6f\t%.6f\t%d\n", e, (long long)im->captured_at_unix_ms, im->exg, im->green_ratio, im->quality_ok ? 1 : 0);
    }
    for (size_t i = 0; i < s_state.alert_count; ++i) {
        size_t index = (s_state.alert_next + SIM_MAX_ALERTS - s_state.alert_count + i) % SIM_MAX_ALERTS;
        const sim_alert_t *a = &s_state.alerts[index];
        fprintf(file, "ALERT\t");
        escape_text(e, sizeof(e), a->id); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), a->title); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), a->message); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), a->severity); fprintf(file, "%s\t%lld\t%d\n", e, (long long)a->created_at_unix_ms, a->acknowledged ? 1 : 0);
    }
    for (size_t i = 0; i < s_state.reading_count; ++i) {
        size_t index = (s_state.reading_next + SIM_MAX_READINGS - s_state.reading_count + i) % SIM_MAX_READINGS;
        const sim_reading_t *r = &s_state.readings[index];
        fprintf(file, "READING\t%lld\t", (long long)r->sampled_at_unix_ms);
        escape_text(e, sizeof(e), r->device_id); fprintf(file, "%s\t", e);
        escape_text(e, sizeof(e), r->plant_id); fprintf(file, "%s\t", e);
        fprintf(file, "%.6f\t%.6f\t%.6f\t%.6f\t%d\t%d\t%d\t%d\t%d\n",
                r->soil_moisture, r->air_temperature,
                r->air_humidity, r->leaf_temperature, r->soil_valid ? 1 : 0,
                r->air_valid ? 1 : 0, r->leaf_valid ? 1 : 0, r->ai_risk_score,
                r->ai_risk_valid ? 1 : 0);
    }
    fprintf(file, "ACK\t");
    escape_text(e, sizeof(e), s_state.last_command_id); fprintf(file, "%s\t", e);
    escape_text(e, sizeof(e), s_state.last_command_status); fprintf(file, "%s\t", e);
    escape_text(e, sizeof(e), s_state.last_command_reason); fprintf(file, "%s\t%lld\n", e, (long long)s_state.last_command_ack_at_unix_ms);
    escape_text(e, sizeof(e), s_state.recommendation); fprintf(file, "AI\t%s\t", e);
    escape_text(e, sizeof(e), s_state.model_version); fprintf(file, "%s\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%d\t", e,
            s_state.exg, s_state.green_ratio, s_state.leaf_air_delta_c,
            s_state.moisture_trend_per_hour, s_state.image_metrics_valid ? 1 : 0,
            s_state.ai_result_received ? 1 : 0);
    escape_text(e, sizeof(e), s_state.ai_plant_id); fprintf(file, "%s\n", e);
    fclose(file);
}

static const char *field_or(char **cursor, const char *fallback)
{
    char *value = next_field(cursor);
    return value ? value : fallback;
}

static void load_fields(char *tag, char *cursor)
{
    if (!tag) return;
    if (strcmp(tag, "SETTINGS") == 0) {
        s_state.settings.notify_app = atoi(field_or(&cursor, "0"));
        s_state.settings.notify_email = atoi(field_or(&cursor, "0"));
        s_state.settings.notify_line = atoi(field_or(&cursor, "0"));
        s_state.settings.pump_enabled = atoi(field_or(&cursor, "0"));
        s_state.settings.auto_irrigation = atoi(field_or(&cursor, "0"));
        unescape_text(s_state.settings.language, sizeof(s_state.settings.language), field_or(&cursor, "ไทย"));
        unescape_text(s_state.settings.display_mode, sizeof(s_state.settings.display_mode), field_or(&cursor, "โหมดสว่าง"));
        s_state.settings.auto_start_moisture = strtod(field_or(&cursor, "35"), NULL);
        s_state.settings.auto_stop_moisture = strtod(field_or(&cursor, "60"), NULL);
        s_state.settings.auto_run_seconds = (uint32_t)strtoul(field_or(&cursor, "10"), NULL, 10);
        s_state.settings.high_risk_score = strtod(field_or(&cursor, "70"), NULL);
    } else if (strcmp(tag, "PLANT") == 0 && s_state.plant_count < SIM_MAX_PLANTS) {
        char *fields[10] = {0};
        size_t count = 0;
        while (count < 10 && (fields[count] = next_field(&cursor)) != NULL) ++count;
        size_t plant_index = s_state.plant_count++;
        sim_plant_t *p = &s_state.plants[plant_index];
        unescape_text(p->id, sizeof(p->id), count > 0 ? fields[0] : "");
        unescape_text(p->name, sizeof(p->name), count > 1 ? fields[1] : "");
        unescape_text(p->zone, sizeof(p->zone), count > 2 ? fields[2] : "");
        if (count >= 8) {
            unescape_text(p->device_id, sizeof(p->device_id), fields[3]);
            unescape_text(p->image_asset, sizeof(p->image_asset), fields[4]);
            unescape_text(p->image_path, sizeof(p->image_path), fields[5]);
            unescape_text(p->health_status, sizeof(p->health_status), fields[6]);
            p->soil_moisture = strtod(fields[7], NULL);
            p->sensor_channel = count > 8 ? (uint8_t)strtoul(fields[8], NULL, 10) : (uint8_t)plant_index;
            p->soil_valid = count > 9 ? atoi(fields[9]) != 0 : false;
        } else {
            unescape_text(p->device_id, sizeof(p->device_id), s_state.device_id);
            unescape_text(p->image_asset, sizeof(p->image_asset), count > 3 ? fields[3] : "");
            p->image_path[0] = '\0';
            unescape_text(p->health_status, sizeof(p->health_status), count > 4 ? fields[4] : "LOW");
            p->soil_moisture = count > 5 ? strtod(fields[5], NULL) : 0;
            p->sensor_channel = (uint8_t)plant_index;
            p->soil_valid = false;
        }
        if (p->sensor_channel >= SIM_MAX_DEVICE_CHANNELS) {
            p->sensor_channel = SIM_MAX_DEVICE_CHANNELS - 1;
        }
    } else if (strcmp(tag, "IMAGE") == 0) {
        sim_image_t *im = &s_state.images[s_state.image_next];
        unescape_text(im->id, sizeof(im->id), field_or(&cursor, ""));
        unescape_text(im->plant_id, sizeof(im->plant_id), field_or(&cursor, ""));
        unescape_text(im->image_path, sizeof(im->image_path), field_or(&cursor, ""));
        unescape_text(im->status, sizeof(im->status), field_or(&cursor, "PENDING"));
        im->captured_at_unix_ms = strtoll(field_or(&cursor, "0"), NULL, 10);
        im->exg = strtod(field_or(&cursor, "0"), NULL);
        im->green_ratio = strtod(field_or(&cursor, "0"), NULL);
        im->quality_ok = atoi(field_or(&cursor, strcmp(im->status, "ANALYZED") == 0 ? "1" : "0")) != 0;
        s_state.image_next = (s_state.image_next + 1) % SIM_MAX_IMAGES;
        if (s_state.image_count < SIM_MAX_IMAGES) ++s_state.image_count;
    } else if (strcmp(tag, "ALERT") == 0) {
        sim_alert_t *a = &s_state.alerts[s_state.alert_next];
        unescape_text(a->id, sizeof(a->id), field_or(&cursor, ""));
        unescape_text(a->title, sizeof(a->title), field_or(&cursor, ""));
        unescape_text(a->message, sizeof(a->message), field_or(&cursor, ""));
        unescape_text(a->severity, sizeof(a->severity), field_or(&cursor, "INFO"));
        a->created_at_unix_ms = strtoll(field_or(&cursor, "0"), NULL, 10);
        a->acknowledged = atoi(field_or(&cursor, "0")) != 0;
        s_state.alert_next = (s_state.alert_next + 1) % SIM_MAX_ALERTS;
        if (s_state.alert_count < SIM_MAX_ALERTS) ++s_state.alert_count;
    } else if (strcmp(tag, "ACK") == 0) {
        unescape_text(s_state.last_command_id, sizeof(s_state.last_command_id), field_or(&cursor, ""));
        unescape_text(s_state.last_command_status, sizeof(s_state.last_command_status), field_or(&cursor, ""));
        unescape_text(s_state.last_command_reason, sizeof(s_state.last_command_reason), field_or(&cursor, ""));
        s_state.last_command_ack_at_unix_ms = strtoll(field_or(&cursor, "0"), NULL, 10);
    } else if (strcmp(tag, "READING") == 0 && s_state.reading_count < SIM_MAX_READINGS) {
        char *fields[12] = {0};
        size_t count = 0;
        while (count < 12 && (fields[count] = next_field(&cursor)) != NULL) ++count;
        sim_reading_t *r = &s_state.readings[s_state.reading_next];
        memset(r, 0, sizeof(*r));
        r->sampled_at_unix_ms = strtoll(count > 0 ? fields[0] : "0", NULL, 10);
        size_t offset = count >= 10 ? 3 : 1;
        if (count >= 10) {
            unescape_text(r->device_id, sizeof(r->device_id), fields[1]);
            unescape_text(r->plant_id, sizeof(r->plant_id), fields[2]);
        } else {
            unescape_text(r->device_id, sizeof(r->device_id), s_state.device_id);
            unescape_text(r->plant_id, sizeof(r->plant_id), s_state.plant_id);
        }
        r->soil_moisture = count > offset ? strtod(fields[offset], NULL) : 0;
        r->air_temperature = count > offset + 1 ? strtod(fields[offset + 1], NULL) : 0;
        r->air_humidity = count > offset + 2 ? strtod(fields[offset + 2], NULL) : 0;
        r->leaf_temperature = count > offset + 3 ? strtod(fields[offset + 3], NULL) : 0;
        r->soil_valid = count > offset + 4 && atoi(fields[offset + 4]) != 0;
        r->air_valid = count > offset + 5 && atoi(fields[offset + 5]) != 0;
        r->leaf_valid = count > offset + 6 && atoi(fields[offset + 6]) != 0;
        r->ai_risk_score = count >= 11 ? atoi(fields[10]) : 0;
        r->ai_risk_valid = count >= 12 && atoi(fields[11]) != 0;
        s_state.reading_next = (s_state.reading_next + 1) % SIM_MAX_READINGS;
        ++s_state.reading_count;
    } else if (strcmp(tag, "AI") == 0) {
        unescape_text(s_state.recommendation, sizeof(s_state.recommendation), field_or(&cursor, "ไม่มีคำแนะนำ"));
        unescape_text(s_state.model_version, sizeof(s_state.model_version), field_or(&cursor, "flora-rules-v1"));
        s_state.exg = strtod(field_or(&cursor, "0"), NULL);
        s_state.green_ratio = strtod(field_or(&cursor, "0"), NULL);
        s_state.leaf_air_delta_c = strtod(field_or(&cursor, "0"), NULL);
        s_state.moisture_trend_per_hour = strtod(field_or(&cursor, "0"), NULL);
        s_state.image_metrics_valid = atoi(field_or(&cursor, "0")) != 0;
        s_state.ai_result_received = atoi(field_or(&cursor, "0")) != 0;
        unescape_text(s_state.ai_plant_id, sizeof(s_state.ai_plant_id), field_or(&cursor, s_state.plant_id));
    }
}

static void sim_store_load(void)
{
    FILE *file = fopen(state_file_path(), "r");
    s_loaded_from_disk = true;
    if (!file) return;
    char line[4096];
    while (fgets(line, sizeof(line), file)) {
        char *cursor = line;
        char *tag = next_field(&cursor);
        if (tag && strcmp(tag, "META") == 0) {
            unescape_text(s_state.device_id, sizeof(s_state.device_id), field_or(&cursor, s_state.device_id));
            unescape_text(s_state.plant_id, sizeof(s_state.plant_id), field_or(&cursor, s_state.plant_id));
            unescape_text(s_state.firmware_version, sizeof(s_state.firmware_version), field_or(&cursor, s_state.firmware_version));
            unescape_text(s_state.device_ip, sizeof(s_state.device_ip), field_or(&cursor, s_state.device_ip));
            s_state.battery_percent = atoi(field_or(&cursor, "0"));
            s_state.mode = flora_mode_from_name(field_or(&cursor, "MANUAL"));
            unescape_text(s_state.pump_state, sizeof(s_state.pump_state), field_or(&cursor, "off"));
            s_state.pump_remaining_seconds = (uint32_t)strtoul(field_or(&cursor, "0"), NULL, 10);
            unescape_text(s_state.risk_level, sizeof(s_state.risk_level), field_or(&cursor, "LOW"));
            s_state.risk_score = atoi(field_or(&cursor, "0"));
            s_state.last_seen_unix_ms = strtoll(field_or(&cursor, "0"), NULL, 10);
            unescape_text(s_state.device_name, sizeof(s_state.device_name), field_or(&cursor, s_state.device_name));
            s_state.plant_count = 0;
        } else {
            load_fields(tag, cursor);
        }
    }
    fclose(file);
}

static void copy_text(char *dst, size_t size, const char *src, const char *fallback)
{
    snprintf(dst, size, "%s", (src && src[0]) ? src : fallback);
}

static void append_alert(const char *title, const char *message, const char *severity)
{
    sim_alert_t *alert = &s_state.alerts[s_state.alert_next];
    memset(alert, 0, sizeof(*alert));
    snprintf(alert->id, sizeof(alert->id), "alert-%lld-%zu", (long long)sim_now_ms(), s_state.alert_next);
    copy_text(alert->title, sizeof(alert->title), title, "Plant alert");
    copy_text(alert->message, sizeof(alert->message), message, "No message");
    copy_text(alert->severity, sizeof(alert->severity), severity, "INFO");
    alert->created_at_unix_ms = sim_now_ms();
    alert->acknowledged = false;
    s_state.alert_next = (s_state.alert_next + 1) % SIM_MAX_ALERTS;
    if (s_state.alert_count < SIM_MAX_ALERTS) ++s_state.alert_count;
}

static void normalize_sensor_channels(void)
{
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        sim_plant_t *plant = &s_state.plants[i];
        if (!plant->image_path[0] && strncmp(plant->image_asset, "assets/", strlen("assets/")) == 0) {
            plant->image_asset[0] = '\0';
        }
        int channel = -1;
        for (uint8_t candidate = 0; candidate < SIM_MAX_DEVICE_CHANNELS; ++candidate) {
            bool used = false;
            for (size_t j = 0; j < i; ++j) {
                if (strcmp(s_state.plants[j].device_id, plant->device_id) == 0 &&
                    s_state.plants[j].sensor_channel == candidate) {
                    used = true;
                    break;
                }
            }
            if (!used) {
                channel = candidate;
                break;
            }
        }
        if (channel >= 0) plant->sensor_channel = (uint8_t)channel;
    }
}

void sim_store_init(void)
{
    memset(&s_state, 0, sizeof(s_state));
    copy_text(s_state.device_id, sizeof(s_state.device_id), default_device_id(), "");
    copy_text(s_state.device_name, sizeof(s_state.device_name), "", "");
    copy_text(s_state.plant_id, sizeof(s_state.plant_id), "", "");
    copy_text(s_state.firmware_version, sizeof(s_state.firmware_version), "unknown", "");
    copy_text(s_state.device_ip, sizeof(s_state.device_ip), "", "");
    s_state.battery_percent = -1;
    copy_text(s_state.pump_state, sizeof(s_state.pump_state), "off", "");
    copy_text(s_state.risk_level, sizeof(s_state.risk_level), "LOW", "");
    copy_text(s_state.recommendation, sizeof(s_state.recommendation), "รอข้อมูลจากอุปกรณ์หรือ simulator", "");
    copy_text(s_state.model_version, sizeof(s_state.model_version), "flora-rules-v1", "");
    s_state.mode = FLORA_MODE_MANUAL;
    s_state.settings.notify_app = true;
    s_state.settings.notify_email = true;
    s_state.settings.notify_line = false;
    s_state.settings.pump_enabled = true;
    s_state.settings.auto_irrigation = false;
    copy_text(s_state.settings.language, sizeof(s_state.settings.language), "ไทย", "");
    copy_text(s_state.settings.display_mode, sizeof(s_state.settings.display_mode), "โหมดสว่าง", "");
    s_state.settings.auto_start_moisture = 35.0;
    s_state.settings.auto_stop_moisture = 60.0;
    s_state.settings.auto_run_seconds = 10;
    s_state.settings.high_risk_score = 70.0;
    s_loaded_from_disk = true;
    s_state.plant_count = 0;
    sim_store_load();
    normalize_sensor_channels();
}

const sim_state_t *sim_store_state(void) { return &s_state; }

void sim_store_add_reading(const sim_reading_t *reading)
{
    if (!reading || !s_state.device_id[0] || !reading->device_id[0] ||
        strcmp(s_state.device_id, reading->device_id) != 0) return;
    s_state.readings[s_state.reading_next] = *reading;
    s_state.last_seen_unix_ms = sim_now_ms();
    s_state.reading_next = (s_state.reading_next + 1) % SIM_MAX_READINGS;
    if (s_state.reading_count < SIM_MAX_READINGS) ++s_state.reading_count;
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        if (reading->plant_id[0] && strcmp(s_state.plants[i].id, reading->plant_id) == 0) {
            s_state.plants[i].soil_moisture = reading->soil_moisture;
            s_state.plants[i].soil_valid = reading->soil_valid;
            if (reading->device_id[0] && strcmp(s_state.plants[i].device_id, reading->device_id) != 0) {
                copy_text(s_state.plants[i].device_id, sizeof(s_state.plants[i].device_id),
                          reading->device_id, s_state.plants[i].device_id);
            }
        }
    }
    if (s_state.mode == FLORA_MODE_AUTO && s_state.settings.auto_irrigation &&
        s_state.settings.pump_enabled && reading->soil_valid &&
        reading->soil_moisture < s_state.settings.auto_start_moisture &&
        strcmp(s_state.pump_state, "running") != 0 &&
        strcmp(s_state.pump_state, "queued") != 0) {
        char reason[FLORA_REASON_MAX] = "";
        sim_store_submit_command(reading->device_id, reading->plant_id, "start",
                                 s_state.settings.auto_run_seconds, reason, sizeof(reason));
    }
    if (s_state.mode == FLORA_MODE_AUTO && s_state.settings.auto_irrigation &&
        s_state.settings.pump_enabled && reading->soil_valid &&
        reading->soil_moisture >= s_state.settings.auto_stop_moisture &&
        strcmp(s_state.pump_state, "running") == 0) {
        char reason[FLORA_REASON_MAX] = "";
        sim_store_submit_command(reading->device_id, reading->plant_id, "stop", 0,
                                 reason, sizeof(reason));
    }
    sim_store_save();
}

const sim_reading_t *sim_store_latest_reading(void)
{
    if (s_state.reading_count == 0) return NULL;
    return &s_state.readings[(s_state.reading_next + SIM_MAX_READINGS - 1) % SIM_MAX_READINGS];
}

void sim_store_set_ai_result(const char *plant_id, const char *level, int score,
                             const char *recommendation, const char *model_version,
                             double exg, double green_ratio,
                             double leaf_air_delta_c, double moisture_trend_per_hour,
                             bool image_metrics_valid)
{
    copy_text(s_state.risk_level, sizeof(s_state.risk_level), level, "LOW");
    if (score < 0) score = 0;
    if (score > 100) score = 100;
    s_state.risk_score = score;
    s_state.ai_result_received = true;
    s_state.exg = exg;
    s_state.green_ratio = green_ratio;
    s_state.leaf_air_delta_c = leaf_air_delta_c;
    s_state.moisture_trend_per_hour = moisture_trend_per_hour;
    s_state.image_metrics_valid = image_metrics_valid;
    copy_text(s_state.model_version, sizeof(s_state.model_version), model_version, "flora-rules-v1");
    copy_text(s_state.recommendation, sizeof(s_state.recommendation), recommendation, "ไม่มีคำแนะนำ");

    sim_plant_t *plant = NULL;
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        if (plant_id && plant_id[0] && strcmp(s_state.plants[i].id, plant_id) == 0) {
            plant = &s_state.plants[i];
            break;
        }
    }
    if (!plant && s_state.plant_count > 0) plant = &s_state.plants[0];
    const char *target_plant_id = plant ? plant->id : plant_id;
    copy_text(s_state.ai_plant_id, sizeof(s_state.ai_plant_id), target_plant_id, "");
    for (size_t i = 0; i < s_state.reading_count; ++i) {
        size_t index = (s_state.reading_next + SIM_MAX_READINGS - 1 - i) % SIM_MAX_READINGS;
        if (!target_plant_id || !target_plant_id[0] || strcmp(s_state.readings[index].plant_id, target_plant_id) == 0) {
            s_state.readings[index].ai_risk_score = score;
            s_state.readings[index].ai_risk_valid = true;
            break;
        }
    }
    bool status_changed = false;
    if (plant) {
        status_changed = strcmp(plant->health_status, s_state.risk_level) != 0;
        copy_text(plant->health_status, sizeof(plant->health_status), s_state.risk_level, "LOW");
    }
    if (status_changed && strcmp(s_state.risk_level, "LOW") != 0 && s_state.settings.notify_app) {
        char message[512];
        snprintf(message, sizeof(message), "%s: %s risk score %d — %s",
                 plant ? plant->name : "Plant", s_state.risk_level, score, s_state.recommendation);
        append_alert("Plant risk", message, score >= (int)s_state.settings.high_risk_score ? "CRITICAL" : "WARNING");
    }
    sim_store_save();
}

static void make_command_id(char *out, size_t size)
{
    static unsigned long counter = 0x1000;
    ++counter;
    snprintf(out, size, "11111111-2222-4333-8444-%012lx", counter & 0xffffffffffffUL);
}

bool sim_store_submit_command(const char *device_id, const char *plant_id,
                              const char *action, uint32_t duration_seconds,
                              char *reason, size_t reason_size)
{
    if (!device_id || !plant_id || !action || !reason || reason_size == 0) return false;
    if (strcmp(action, "start") != 0 && strcmp(action, "stop") != 0) {
        snprintf(reason, reason_size, "UNSUPPORTED_ACTION");
        return false;
    }
    if (strcmp(action, "start") == 0 && !s_state.settings.pump_enabled) {
        snprintf(reason, reason_size, "PUMP_DISABLED");
        return false;
    }
    if (s_state.pending_command.pending) {
        if (s_state.pending_command.expires_at_unix_ms <= sim_now_ms()) {
            s_state.pending_command.pending = false;
            copy_text(s_state.pump_state, sizeof(s_state.pump_state), "off", "off");
            s_state.pump_remaining_seconds = 0;
        } else if (strcmp(action, "start") == 0) {
            snprintf(reason, reason_size, "COMMAND_PENDING");
            return false;
        }
    }
    flora_pump_command_t command = {0};
    make_command_id(command.command_id, sizeof(command.command_id));
    copy_text(command.device_id, sizeof(command.device_id), device_id, "");
    copy_text(command.plant_id, sizeof(command.plant_id), plant_id, "");
    snprintf(command.idempotency_key, sizeof(command.idempotency_key), "sim-%lld", (long long)sim_now_ms());
    command.mode = s_state.mode;
    command.start = strcmp(action, "start") == 0;
    command.duration_seconds = duration_seconds;
    command.issued_at_unix_ms = sim_now_ms();
    command.expires_at_unix_ms = command.issued_at_unix_ms + 30000;
    flora_policy_context_t context = {
        .mode = s_state.mode,
        .test_interlock = s_state.mode == FLORA_MODE_TEST,
        .max_run_seconds = 120,
        .cooldown_seconds = 0,
        .last_completed_at_unix_ms = 0,
        .soil_valid = true,
        .cloud_authenticated = true,
    };
    flora_policy_result_t decision = command_policy_validate(&command, &context, command.issued_at_unix_ms);
    if (!decision.allowed) {
        snprintf(reason, reason_size, "%s", flora_reject_reason_name(decision.reason));
        return false;
    }
    sim_command_t pending = {0};
    copy_text(pending.command_id, sizeof(pending.command_id), command.command_id, "");
    copy_text(pending.device_id, sizeof(pending.device_id), command.device_id, "");
    copy_text(pending.plant_id, sizeof(pending.plant_id), command.plant_id, "");
    pending.mode = command.mode;
    pending.start = command.start;
    pending.duration_seconds = command.duration_seconds;
    pending.issued_at_unix_ms = command.issued_at_unix_ms;
    pending.expires_at_unix_ms = command.expires_at_unix_ms;
    pending.status = FLORA_COMMAND_QUEUED;
    pending.pending = true;
    copy_text(pending.reason, sizeof(pending.reason), "QUEUED", "");
    s_state.pending_command = pending;
    copy_text(s_state.pump_state, sizeof(s_state.pump_state), "queued", "off");
    s_state.pump_remaining_seconds = duration_seconds;
    snprintf(reason, reason_size, "QUEUED:%s", command.command_id);
    return true;
}

bool sim_store_pop_pending_command(const char *device_id, sim_command_t *out)
{
    if (!device_id || !out || !s_state.pending_command.pending) return false;
    if (strncmp(s_state.pending_command.device_id, device_id, FLORA_ID_MAX) != 0) return false;
    if (s_state.pending_command.expires_at_unix_ms <= sim_now_ms()) {
        s_state.pending_command.pending = false;
        copy_text(s_state.pending_command.reason, sizeof(s_state.pending_command.reason), "EXPIRED", "");
        copy_text(s_state.pump_state, sizeof(s_state.pump_state), "off", "off");
        s_state.pump_remaining_seconds = 0;
        sim_store_save();
        return false;
    }
    *out = s_state.pending_command;
    s_state.pending_command.pending = false;
    return true;
}

void sim_store_update_pump_status(const char *state, uint32_t remaining_seconds)
{
    copy_text(s_state.pump_state, sizeof(s_state.pump_state), state, "off");
    s_state.pump_remaining_seconds = remaining_seconds;
    sim_store_save();
}

void sim_store_update_device_status(const char *device_id, const char *name,
                                    const char *firmware_version, const char *ip,
                                    int battery_percent)
{
    if (!device_id || !device_id[0] || strcmp(device_id, s_state.device_id) != 0) return;
    if (name && name[0]) copy_text(s_state.device_name, sizeof(s_state.device_name), name, s_state.device_name);
    if (firmware_version && firmware_version[0]) copy_text(s_state.firmware_version, sizeof(s_state.firmware_version), firmware_version, s_state.firmware_version);
    if (ip) copy_text(s_state.device_ip, sizeof(s_state.device_ip), ip, s_state.device_ip);
    s_state.battery_percent = battery_percent;
    s_state.last_seen_unix_ms = sim_now_ms();
    sim_store_save();
}

static void clear_device_runtime(void)
{
    s_state.last_seen_unix_ms = 0;
    s_state.firmware_version[0] = '\0';
    s_state.device_ip[0] = '\0';
    s_state.battery_percent = -1;
    copy_text(s_state.pump_state, sizeof(s_state.pump_state), "off", "off");
    s_state.pump_remaining_seconds = 0;
    memset(&s_state.pending_command, 0, sizeof(s_state.pending_command));
    s_state.reboot_pending = false;
    s_state.last_command_id[0] = '\0';
    s_state.last_command_status[0] = '\0';
    s_state.last_command_reason[0] = '\0';
    s_state.last_command_ack_at_unix_ms = 0;
}

bool sim_store_register_device(const char *id, const char *name,
                               char *error, size_t error_size)
{
    if (!id || !id[0]) {
        snprintf(error, error_size, "INVALID_DEVICE");
        return false;
    }
    if (s_state.device_id[0]) {
        snprintf(error, error_size, "DEVICE_ALREADY_REGISTERED");
        return false;
    }
    copy_text(s_state.device_id, sizeof(s_state.device_id), id, "");
    copy_text(s_state.device_name, sizeof(s_state.device_name), name, id);
    clear_device_runtime();
    sim_store_save();
    return true;
}

bool sim_store_update_device(const char *id, const char *new_id, const char *name,
                             char *error, size_t error_size)
{
    if (!id || !id[0] || strcmp(id, s_state.device_id) != 0) {
        snprintf(error, error_size, "DEVICE_NOT_FOUND");
        return false;
    }
    const char *target_id = new_id && new_id[0] ? new_id : id;
    bool online = s_state.last_seen_unix_ms > 0 &&
                  sim_now_ms() - s_state.last_seen_unix_ms <= 30000;
    if (strcmp(target_id, id) != 0 && online) {
        snprintf(error, error_size, "DEVICE_ONLINE");
        return false;
    }
    if (strcmp(target_id, id) != 0) {
        copy_text(s_state.device_id, sizeof(s_state.device_id), target_id, s_state.device_id);
        for (size_t i = 0; i < s_state.plant_count; ++i) {
            if (strcmp(s_state.plants[i].device_id, id) == 0) {
                copy_text(s_state.plants[i].device_id,
                          sizeof(s_state.plants[i].device_id), target_id, target_id);
            }
        }
        for (size_t i = 0; i < s_state.reading_count; ++i) {
            size_t index = (s_state.reading_next + SIM_MAX_READINGS - s_state.reading_count + i) % SIM_MAX_READINGS;
            if (strcmp(s_state.readings[index].device_id, id) == 0) {
                copy_text(s_state.readings[index].device_id,
                          sizeof(s_state.readings[index].device_id), target_id, target_id);
            }
        }
        if (strcmp(s_state.pending_command.device_id, id) == 0) {
            copy_text(s_state.pending_command.device_id,
                      sizeof(s_state.pending_command.device_id), target_id, target_id);
        }
        clear_device_runtime();
    }
    copy_text(s_state.device_name, sizeof(s_state.device_name), name, target_id);
    sim_store_save();
    return true;
}

bool sim_store_delete_device(const char *id, char *error, size_t error_size)
{
    if (!id || !id[0] || strcmp(id, s_state.device_id) != 0) {
        snprintf(error, error_size, "DEVICE_NOT_FOUND");
        return false;
    }
    bool online = s_state.last_seen_unix_ms > 0 &&
                  sim_now_ms() - s_state.last_seen_unix_ms <= 30000;
    if (online) {
        snprintf(error, error_size, "DEVICE_ONLINE");
        return false;
    }
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        if (strcmp(s_state.plants[i].device_id, id) == 0) {
            snprintf(error, error_size, "DEVICE_IN_USE");
            return false;
        }
    }
    s_state.device_id[0] = '\0';
    s_state.device_name[0] = '\0';
    clear_device_runtime();
    sim_store_save();
    return true;
}

int sim_store_available_sensor_channel(const char *device_id)
{
    if (!device_id || !device_id[0]) return -1;
    for (uint8_t channel = 0; channel < SIM_MAX_DEVICE_CHANNELS; ++channel) {
        bool used = false;
        for (size_t i = 0; i < s_state.plant_count; ++i) {
            const sim_plant_t *plant = &s_state.plants[i];
            if (strcmp(plant->device_id, device_id) == 0 && plant->sensor_channel == channel) {
                used = true;
                break;
            }
        }
        if (!used) return channel;
    }
    return -1;
}

bool sim_store_add_plant(const char *name, const char *zone, const char *device_id,
                         const char *image_asset, const char *image_path,
                         const char *health_status, double soil_moisture,
                         char *id, size_t id_size)
{
    if (!name || !name[0] || !zone || !zone[0] || !device_id || !device_id[0] ||
        strcmp(device_id, s_state.device_id) != 0 || s_state.plant_count >= SIM_MAX_PLANTS) return false;
    int channel = sim_store_available_sensor_channel(device_id);
    if (channel < 0) return false;
    sim_plant_t *plant = &s_state.plants[s_state.plant_count++];
    memset(plant, 0, sizeof(*plant));
    snprintf(plant->id, sizeof(plant->id), "plant-%zu", s_state.plant_count);
    copy_text(plant->name, sizeof(plant->name), name, "Plant");
    copy_text(plant->zone, sizeof(plant->zone), zone, "Unassigned");
    copy_text(plant->device_id, sizeof(plant->device_id), device_id, s_state.device_id);
    copy_text(plant->image_asset, sizeof(plant->image_asset), image_asset, "");
    copy_text(plant->image_path, sizeof(plant->image_path), image_path, "");
    copy_text(plant->health_status, sizeof(plant->health_status), health_status, "LOW");
    plant->soil_moisture = soil_moisture;
    plant->sensor_channel = (uint8_t)channel;
    plant->soil_valid = false;
    if (id && id_size) snprintf(id, id_size, "%s", plant->id);
    sim_store_save();
    return true;
}

bool sim_store_update_plant(const char *id, const char *name, const char *zone,
                            const char *device_id, const char *image_path,
                            const char *health_status, int *sensor_channel)
{
    if (!id || !id[0] || !name || !name[0] || !zone || !zone[0]) return false;
    sim_plant_t *plant = NULL;
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        if (strcmp(s_state.plants[i].id, id) == 0) {
            plant = &s_state.plants[i];
            break;
        }
    }
    if (!plant) return false;

    const char *target_device = device_id && device_id[0] ? device_id : plant->device_id;
    if (strcmp(target_device, s_state.device_id) != 0) return false;
    int channel = plant->sensor_channel;
    bool device_changed = strcmp(target_device, plant->device_id) != 0;
    if (device_changed) {
        channel = sim_store_available_sensor_channel(target_device);
        if (channel < 0) return false;
    }

    copy_text(plant->name, sizeof(plant->name), name, plant->name);
    copy_text(plant->zone, sizeof(plant->zone), zone, plant->zone);
    copy_text(plant->device_id, sizeof(plant->device_id), target_device, plant->device_id);
    if (image_path && image_path[0]) {
        copy_text(plant->image_path, sizeof(plant->image_path), image_path, plant->image_path);
        plant->image_asset[0] = '\0';
    }
    copy_text(plant->health_status, sizeof(plant->health_status), health_status, plant->health_status);
    if (device_changed) {
        plant->sensor_channel = (uint8_t)channel;
        plant->soil_moisture = 0;
        plant->soil_valid = false;
    }
    if (sensor_channel) *sensor_channel = plant->sensor_channel;
    sim_store_save();
    return true;
}

bool sim_store_delete_plant(const char *id)
{
    if (!id || !id[0]) return false;
    size_t found = s_state.plant_count;
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        if (strcmp(s_state.plants[i].id, id) == 0) {
            found = i;
            break;
        }
    }
    if (found == s_state.plant_count) return false;

    for (size_t i = found + 1; i < s_state.plant_count; ++i) {
        s_state.plants[i - 1] = s_state.plants[i];
    }
    --s_state.plant_count;
    memset(&s_state.plants[s_state.plant_count], 0, sizeof(s_state.plants[s_state.plant_count]));

    sim_image_t kept[SIM_MAX_IMAGES] = {0};
    size_t kept_count = 0;
    for (size_t i = 0; i < s_state.image_count; ++i) {
        size_t index = (s_state.image_next + SIM_MAX_IMAGES - s_state.image_count + i) % SIM_MAX_IMAGES;
        if (strcmp(s_state.images[index].plant_id, id) != 0) {
            kept[kept_count++] = s_state.images[index];
        }
    }
    memset(s_state.images, 0, sizeof(s_state.images));
    memcpy(s_state.images, kept, sizeof(kept));
    s_state.image_count = kept_count;
    s_state.image_next = kept_count % SIM_MAX_IMAGES;

    if (strcmp(s_state.ai_plant_id, id) == 0) {
        s_state.ai_plant_id[0] = '\0';
        s_state.ai_result_received = false;
        s_state.image_metrics_valid = false;
        s_state.risk_score = 0;
        copy_text(s_state.risk_level, sizeof(s_state.risk_level), "LOW", "LOW");
        copy_text(s_state.recommendation, sizeof(s_state.recommendation), "รอข้อมูลจากอุปกรณ์หรือ simulator", "");
    }
    sim_store_save();
    return true;
}

bool sim_store_add_image(const char *plant_id, const char *image_path, const char *status,
                         double exg, double green_ratio, char *id, size_t id_size)
{
    if (!plant_id || !plant_id[0] || !image_path || !image_path[0]) return false;
    sim_image_t *image = &s_state.images[s_state.image_next];
    memset(image, 0, sizeof(*image));
    snprintf(image->id, sizeof(image->id), "image-%lld-%zu", (long long)sim_now_ms(), s_state.image_next);
    copy_text(image->plant_id, sizeof(image->plant_id), plant_id, "");
    copy_text(image->image_path, sizeof(image->image_path), image_path, "");
    copy_text(image->status, sizeof(image->status), status, "PENDING");
    image->captured_at_unix_ms = sim_now_ms();
    image->exg = exg;
    image->green_ratio = green_ratio;
    s_state.image_next = (s_state.image_next + 1) % SIM_MAX_IMAGES;
    if (s_state.image_count < SIM_MAX_IMAGES) ++s_state.image_count;
    if (id && id_size) snprintf(id, id_size, "%s", image->id);
    sim_store_save();
    return true;
}

bool sim_store_acknowledge_alert(const char *id)
{
    if (!id || !id[0]) return false;
    for (size_t i = 0; i < s_state.alert_count; ++i) {
        size_t index = (s_state.alert_next + SIM_MAX_ALERTS - s_state.alert_count + i) % SIM_MAX_ALERTS;
        if (strcmp(s_state.alerts[index].id, id) == 0) {
            s_state.alerts[index].acknowledged = true;
            sim_store_save();
            return true;
        }
    }
    return false;
}

static bool json_bool_field(const char *body, const char *key, bool *out)
{
    char pattern[96];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *pos = body ? strstr(body, pattern) : NULL;
    if (!pos) return false;
    pos = strchr(pos + strlen(pattern), ':');
    if (!pos) return false;
    ++pos;
    while (*pos == ' ' || *pos == '\t') ++pos;
    if (strncmp(pos, "true", 4) == 0) { *out = true; return true; }
    if (strncmp(pos, "false", 5) == 0) { *out = false; return true; }
    return false;
}

static bool json_number_field(const char *body, const char *key, double *out)
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

static bool json_string_field(const char *body, const char *key, char *out, size_t size)
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
    while (pos[len] && pos[len] != '"' && len + 1 < size) { out[len] = pos[len]; ++len; }
    out[len] = '\0';
    return pos[len] == '"';
}

bool sim_store_update_settings(const char *body, char *error, size_t error_size)
{
    sim_settings_t next = s_state.settings;
    bool changed = false;
    if (json_bool_field(body, "notifyApp", &next.notify_app)) changed = true;
    if (json_bool_field(body, "notifyEmail", &next.notify_email)) changed = true;
    if (json_bool_field(body, "notifyLine", &next.notify_line)) changed = true;
    if (json_bool_field(body, "pumpEnabled", &next.pump_enabled)) changed = true;
    if (json_bool_field(body, "autoIrrigation", &next.auto_irrigation)) changed = true;
    if (json_string_field(body, "language", next.language, sizeof(next.language))) changed = true;
    if (json_string_field(body, "displayMode", next.display_mode, sizeof(next.display_mode))) changed = true;
    if (json_number_field(body, "autoStartMoisture", &next.auto_start_moisture)) changed = true;
    if (json_number_field(body, "autoStopMoisture", &next.auto_stop_moisture)) changed = true;
    double run_seconds = next.auto_run_seconds;
    if (json_number_field(body, "autoRunSeconds", &run_seconds)) changed = true;
    if (json_number_field(body, "highRiskScore", &next.high_risk_score)) changed = true;
    if (!changed) {
        snprintf(error, error_size, "NO_VALID_FIELDS");
        return false;
    }
    if (strcmp(next.language, "ไทย") != 0 && strcmp(next.language, "English") != 0) {
        snprintf(error, error_size, "INVALID_LANGUAGE");
        return false;
    }
    if (strcmp(next.display_mode, "โหมดสว่าง") != 0 && strcmp(next.display_mode, "โหมดมืด") != 0 && strcmp(next.display_mode, "ตามระบบ") != 0) {
        snprintf(error, error_size, "INVALID_DISPLAY_MODE");
        return false;
    }
    if (next.auto_start_moisture < 0 || next.auto_start_moisture > 100 ||
        next.auto_stop_moisture < 0 || next.auto_stop_moisture > 100 ||
        next.auto_start_moisture >= next.auto_stop_moisture) {
        snprintf(error, error_size, "INVALID_MOISTURE_RANGE");
        return false;
    }
    if (run_seconds <= 0 || run_seconds > 120) {
        snprintf(error, error_size, "INVALID_AUTO_RUN_SECONDS");
        return false;
    }
    if (next.high_risk_score < 1 || next.high_risk_score > 100) {
        snprintf(error, error_size, "INVALID_HIGH_RISK_SCORE");
        return false;
    }
    next.auto_run_seconds = (uint32_t)run_seconds;
    s_state.settings = next;
    sim_store_save();
    return true;
}

void sim_store_request_reboot(void)
{
    s_state.reboot_pending = true;
    sim_store_save();
}

bool sim_store_pop_reboot(void)
{
    bool pending = s_state.reboot_pending;
    s_state.reboot_pending = false;
    if (pending) sim_store_save();
    return pending;
}

bool sim_store_set_mode(const char *mode_name, char *error, size_t error_size)
{
    if (!mode_name || (strcmp(mode_name, "TEST") != 0 && strcmp(mode_name, "MANUAL") != 0 && strcmp(mode_name, "AUTO") != 0)) {
        snprintf(error, error_size, "INVALID_MODE");
        return false;
    }
    s_state.mode = flora_mode_from_name(mode_name);
    s_state.settings.auto_irrigation = s_state.mode == FLORA_MODE_AUTO;
    sim_store_save();
    return true;
}

int sim_store_dashboard_json(char *out, size_t size)
{
    const sim_reading_t *latest = sim_store_latest_reading();
    size_t open_alerts = 0;
    for (size_t i = 0; i < s_state.alert_count; ++i) {
        size_t index = (s_state.alert_next + SIM_MAX_ALERTS - s_state.alert_count + i) % SIM_MAX_ALERTS;
        if (!s_state.alerts[index].acknowledged) ++open_alerts;
    }
    const sim_reading_t zero = {0};
    const sim_reading_t *r = latest ? latest : &zero;
    return snprintf(out, size,
        "{\"plants\":%zu,\"devicesOnline\":%d,\"devicesTotal\":%d,\"openAlerts\":%zu,"
        "\"riskLevel\":\"%s\",\"riskScore\":%d,\"recommendation\":\"%s\","
        "\"pumpState\":\"%s\",\"pumpRemainingSeconds\":%u,\"mode\":\"%s\","
        "\"modelVersion\":\"%s\",\"aiResultReceived\":%s,\"imageMetricsValid\":%s,\"aiPlantId\":\"%s\","
        "\"features\":{\"exg\":%.4f,\"green_ratio\":%.4f,\"leaf_air_delta_c\":%.3f,\"moisture_trend_per_hour\":%.3f},"
        "\"latest\":{\"soil_moisture\":%.2f,\"air_temperature\":%.2f,\"air_humidity\":%.2f,\"leaf_temperature\":%.2f}}",
        s_state.plant_count,
        (s_state.last_seen_unix_ms > 0 && sim_now_ms() - s_state.last_seen_unix_ms <= 30000) ? 1 : 0,
        s_state.device_id[0] ? 1 : 0,
        open_alerts, s_state.risk_level, s_state.risk_score,
        s_state.recommendation, s_state.pump_state, s_state.pump_remaining_seconds,
        flora_mode_name(s_state.mode), s_state.model_version,
        s_state.ai_result_received ? "true" : "false",
        s_state.image_metrics_valid ? "true" : "false", s_state.ai_plant_id,
        s_state.exg, s_state.green_ratio,
        s_state.leaf_air_delta_c, s_state.moisture_trend_per_hour,
        r->soil_moisture, r->air_temperature, r->air_humidity, r->leaf_temperature);
}

int sim_store_readings_json(char *out, size_t size)
{
    size_t used = (size_t)snprintf(out, size, "[");
    for (size_t i = 0; i < s_state.reading_count && used < size - 160; ++i) {
        size_t index = (s_state.reading_next + SIM_MAX_READINGS - s_state.reading_count + i) % SIM_MAX_READINGS;
        const sim_reading_t *r = &s_state.readings[index];
        used += (size_t)snprintf(out + used, size - used,
            "%s{\"sampled_at_unix_ms\":%lld,\"deviceId\":\"%s\",\"plantId\":\"%s\",\"soil_moisture\":%.2f,\"air_temperature\":%.2f,\"air_humidity\":%.2f,\"leaf_temperature\":%.2f}",
            i ? "," : "", (long long)r->sampled_at_unix_ms, r->device_id, r->plant_id,
            r->soil_moisture, r->air_temperature, r->air_humidity, r->leaf_temperature);
    }
    snprintf(out + used, size - used, "]");
    return (int)used + 1;
}

int sim_store_plants_json(char *out, size_t size)
{
    size_t used = (size_t)snprintf(out, size, "[");
    for (size_t i = 0; i < s_state.plant_count && used < size - 256; ++i) {
        const sim_plant_t *p = &s_state.plants[i];
        used += (size_t)snprintf(out + used, size - used,
            "%s{\"id\":\"%s\",\"name\":\"%s\",\"zone\":\"%s\",\"deviceId\":\"%s\",\"imageAsset\":\"%s\",\"imagePath\":\"%s\",\"healthStatus\":\"%s\",\"soilMoisture\":%.2f,\"sensorChannel\":%u,\"soilValid\":%s}",
            i ? "," : "", p->id, p->name, p->zone, p->device_id, p->image_asset,
            p->image_path, p->health_status, p->soil_moisture, p->sensor_channel,
            p->soil_valid ? "true" : "false");
    }
    snprintf(out + used, size - used, "]");
    return (int)used + 1;
}

int sim_store_images_json(char *out, size_t size)
{
    size_t used = (size_t)snprintf(out, size, "[");
    for (size_t i = 0; i < s_state.image_count && used < size - 256; ++i) {
        size_t index = (s_state.image_next + SIM_MAX_IMAGES - s_state.image_count + i) % SIM_MAX_IMAGES;
        const sim_image_t *image = &s_state.images[index];
        used += (size_t)snprintf(out + used, size - used,
            "%s{\"id\":\"%s\",\"plantId\":\"%s\",\"imagePath\":\"%s\",\"status\":\"%s\",\"capturedAt\":%lld,\"exg\":%.4f,\"greenRatio\":%.4f,\"qualityOk\":%s}",
            i ? "," : "", image->id, image->plant_id, image->image_path, image->status,
            (long long)image->captured_at_unix_ms, image->exg, image->green_ratio,
            image->quality_ok ? "true" : "false");
    }
    snprintf(out + used, size - used, "]");
    return (int)used + 1;
}

int sim_store_alerts_json(char *out, size_t size)
{
    size_t used = (size_t)snprintf(out, size, "[");
    size_t written = 0;
    for (size_t i = s_state.alert_count; i > 0 && used < size - 512; --i) {
        size_t index = (s_state.alert_next + SIM_MAX_ALERTS - i) % SIM_MAX_ALERTS;
        const sim_alert_t *a = &s_state.alerts[index];
        used += (size_t)snprintf(out + used, size - used,
            "%s{\"id\":\"%s\",\"title\":\"%s\",\"message\":\"%s\",\"severity\":\"%s\",\"acknowledged\":%s,\"createdAt\":%lld}",
            written++ ? "," : "", a->id, a->title, a->message, a->severity,
            a->acknowledged ? "true" : "false", (long long)a->created_at_unix_ms);
    }
    snprintf(out + used, size - used, "]");
    return (int)used + 1;
}

void sim_store_record_command_ack(const char *command_id, const char *status, const char *reason)
{
    copy_text(s_state.last_command_id, sizeof(s_state.last_command_id), command_id, "");
    copy_text(s_state.last_command_status, sizeof(s_state.last_command_status), status, "UNKNOWN");
    copy_text(s_state.last_command_reason, sizeof(s_state.last_command_reason), reason, "NONE");
    s_state.last_command_ack_at_unix_ms = sim_now_ms();
    if (s_state.pending_command.command_id[0] &&
        strncmp(s_state.pending_command.command_id, s_state.last_command_id, FLORA_ID_MAX) == 0) {
        s_state.pending_command.pending = false;
        copy_text(s_state.pending_command.reason, sizeof(s_state.pending_command.reason), s_state.last_command_reason, "NONE");
    }
    sim_store_save();
}

bool sim_store_update_image_metrics(const char *id, const char *status, double exg,
                                    double green_ratio, bool quality_ok)
{
    if (!id || !id[0]) return false;
    for (size_t i = 0; i < s_state.image_count; ++i) {
        size_t index = (s_state.image_next + SIM_MAX_IMAGES - s_state.image_count + i) % SIM_MAX_IMAGES;
        if (strncmp(s_state.images[index].id, id, FLORA_ID_MAX) != 0) continue;
        s_state.images[index].exg = exg;
        s_state.images[index].green_ratio = green_ratio;
        s_state.images[index].quality_ok = quality_ok;
        copy_text(s_state.images[index].status, sizeof(s_state.images[index].status), status, "ANALYZED");
        if (strcmp(s_state.images[index].status, "ANALYZED") == 0) {
            s_state.exg = exg;
            s_state.green_ratio = green_ratio;
            s_state.image_metrics_valid = quality_ok;
        }
        sim_store_save();
        return true;
    }
    return false;
}

bool sim_store_update_image(const char *id, const char *plant_id, const char *image_path)
{
    if (!id || !id[0] || !plant_id || !plant_id[0]) return false;
    for (size_t i = 0; i < s_state.image_count; ++i) {
        size_t index = (s_state.image_next + SIM_MAX_IMAGES - s_state.image_count + i) % SIM_MAX_IMAGES;
        sim_image_t *image = &s_state.images[index];
        if (strncmp(image->id, id, FLORA_ID_MAX) != 0) continue;
        char old_path[sizeof(image->image_path)] = "";
        snprintf(old_path, sizeof(old_path), "%s", image->image_path);
        copy_text(image->plant_id, sizeof(image->plant_id), plant_id, image->plant_id);
        if (image_path && image_path[0]) {
            copy_text(image->image_path, sizeof(image->image_path), image_path, image->image_path);
            copy_text(image->status, sizeof(image->status), "UPLOADED", "UPLOADED");
            image->captured_at_unix_ms = sim_now_ms();
            image->exg = 0;
            image->green_ratio = 0;
            image->quality_ok = false;
            for (size_t plant_index = 0; plant_index < s_state.plant_count; ++plant_index) {
                if (strcmp(s_state.plants[plant_index].image_path, old_path) == 0) {
                    copy_text(s_state.plants[plant_index].image_path,
                              sizeof(s_state.plants[plant_index].image_path), image->image_path, "");
                }
            }
        }
        sim_store_save();
        return true;
    }
    return false;
}

bool sim_store_delete_image(const char *id)
{
    if (!id || !id[0]) return false;
    char removed_path[192] = "";
    sim_image_t kept[SIM_MAX_IMAGES] = {0};
    size_t kept_count = 0;
    bool removed = false;
    for (size_t i = 0; i < s_state.image_count; ++i) {
        size_t index = (s_state.image_next + SIM_MAX_IMAGES - s_state.image_count + i) % SIM_MAX_IMAGES;
        if (strcmp(s_state.images[index].id, id) == 0) {
            snprintf(removed_path, sizeof(removed_path), "%s", s_state.images[index].image_path);
            removed = true;
            continue;
        }
        kept[kept_count++] = s_state.images[index];
    }
    if (!removed) return false;
    memset(s_state.images, 0, sizeof(s_state.images));
    memcpy(s_state.images, kept, sizeof(kept));
    s_state.image_count = kept_count;
    s_state.image_next = kept_count % SIM_MAX_IMAGES;
    for (size_t i = 0; i < s_state.plant_count; ++i) {
        if (strcmp(s_state.plants[i].image_path, removed_path) == 0) {
            s_state.plants[i].image_path[0] = '\0';
        }
    }
    s_state.image_metrics_valid = false;
    s_state.exg = 0;
    s_state.green_ratio = 0;
    for (size_t i = s_state.image_count; i > 0; --i) {
        size_t index = (s_state.image_next + SIM_MAX_IMAGES - i) % SIM_MAX_IMAGES;
        if (strcmp(s_state.images[index].status, "ANALYZED") == 0 &&
            s_state.images[index].quality_ok) {
            s_state.exg = s_state.images[index].exg;
            s_state.green_ratio = s_state.images[index].green_ratio;
            s_state.image_metrics_valid = true;
            break;
        }
    }
    sim_store_save();
    return true;
}

int sim_store_devices_json(char *out, size_t size)
{
    if (!s_state.device_id[0]) return snprintf(out, size, "[]");
    const sim_reading_t *latest = sim_store_latest_reading();
    const char *soil_status = latest && latest->soil_valid ? "online" : "offline";
    const char *air_status = latest && latest->air_valid ? "online" : "offline";
    const char *leaf_status = latest && latest->leaf_valid ? "online" : "offline";
    const char *camera_status = s_state.image_count > 0 ? "online" : "offline";
    bool online = s_state.last_seen_unix_ms > 0 && sim_now_ms() - s_state.last_seen_unix_ms <= 30000;
    char device_name[128];
    char firmware[48];
    char ip[80];
    escape_text(device_name, sizeof(device_name), s_state.device_name[0] ? s_state.device_name : s_state.device_id);
    escape_text(firmware, sizeof(firmware), online ? s_state.firmware_version : "");
    escape_text(ip, sizeof(ip), online ? s_state.device_ip : "");
    return snprintf(out, size,
        "[{\"id\":\"%s\",\"name\":\"%s\",\"online\":%s,\"firmware\":\"%s\",\"ip\":\"%s\",\"battery\":%d,\"mode\":\"%s\",\"pumpState\":\"%s\",\"lastSeenUnixMs\":%lld,\"lastCommandId\":\"%s\",\"lastCommandStatus\":\"%s\",\"lastCommandReason\":\"%s\",\"lastCommandAckAt\":%lld,"
        "\"sensors\":[{\"id\":\"soil\",\"name\":\"Soil Moisture\",\"status\":\"%s\"},{\"id\":\"air\",\"name\":\"DHT22 Air\",\"status\":\"%s\"},{\"id\":\"leaf\",\"name\":\"Leaf Temperature Probe\",\"status\":\"%s\"},{\"id\":\"camera\",\"name\":\"Camera\",\"status\":\"%s\"}]}]",
        s_state.device_id, device_name,
        online ? "true" : "false",
        firmware, ip, online ? s_state.battery_percent : -1,
        flora_mode_name(s_state.mode), s_state.pump_state, (long long)s_state.last_seen_unix_ms,
        s_state.last_command_id, s_state.last_command_status, s_state.last_command_reason,
        (long long)s_state.last_command_ack_at_unix_ms,
        soil_status, air_status, leaf_status, camera_status);
}

int sim_store_settings_json(char *out, size_t size)
{
    const sim_settings_t *s = &s_state.settings;
    return snprintf(out, size,
        "{\"notifyApp\":%s,\"notifyEmail\":%s,\"notifyLine\":%s,\"pumpEnabled\":%s,\"autoIrrigation\":%s,\"language\":\"%s\",\"displayMode\":\"%s\",\"autoStartMoisture\":%.2f,\"autoStopMoisture\":%.2f,\"autoRunSeconds\":%u,\"highRiskScore\":%.2f}",
        s->notify_app ? "true" : "false", s->notify_email ? "true" : "false",
        s->notify_line ? "true" : "false", s->pump_enabled ? "true" : "false",
        s->auto_irrigation ? "true" : "false", s->language, s->display_mode,
        s->auto_start_moisture, s->auto_stop_moisture, s->auto_run_seconds, s->high_risk_score);
}

int sim_store_report_json(const char *range_name, char *out, size_t size)
{
    size_t days = 7;
    if (range_name && strstr(range_name, "30")) days = 30;
    else if (range_name && strstr(range_name, "90")) days = 90;
    else if (range_name && strstr(range_name, "365")) days = 365;
    int64_t cutoff = sim_now_ms() - (int64_t)days * 86400000;
    size_t count = 0;
    size_t healthy_count = 0, medium_count = 0, high_count = 0;
    double soil_sum = 0, air_sum = 0, humidity_sum = 0, leaf_sum = 0;
    size_t used = (size_t)snprintf(out, size, "{\"range\":\"%s\",\"series\":[", range_name ? range_name : "7d");
    for (size_t i = 0; i < s_state.reading_count && used < size - 256; ++i) {
        size_t index = (s_state.reading_next + SIM_MAX_READINGS - s_state.reading_count + i) % SIM_MAX_READINGS;
        const sim_reading_t *r = &s_state.readings[index];
        if (r->sampled_at_unix_ms < cutoff) continue;
        ++count;
        soil_sum += r->soil_moisture; air_sum += r->air_temperature; humidity_sum += r->air_humidity; leaf_sum += r->leaf_temperature;
        int risk = r->ai_risk_valid ? r->ai_risk_score : s_state.risk_score;
        if (risk >= (int)s_state.settings.high_risk_score) ++high_count;
        else if (risk >= 40) ++medium_count;
        else ++healthy_count;
        used += (size_t)snprintf(out + used, size - used,
            "%s{\"timestamp\":%lld,\"plantId\":\"%s\",\"soil\":%.2f,\"air\":%.2f,\"humidity\":%.2f,\"leaf\":%.2f,\"risk\":%d}",
            count > 1 ? "," : "", (long long)r->sampled_at_unix_ms, r->plant_id,
            r->soil_moisture, r->air_temperature, r->air_humidity, r->leaf_temperature, risk);
    }
    if (!count) count = 1;
    snprintf(out + used, size - used,
        "],\"summary\":{\"soilAverage\":%.2f,\"airAverage\":%.2f,\"humidityAverage\":%.2f,\"leafAverage\":%.2f,\"healthyPercent\":%d,\"mediumPercent\":%d,\"highPercent\":%d}}",
        soil_sum / count, air_sum / count, humidity_sum / count, leaf_sum / count,
        (int)(healthy_count * 100 / count), (int)(medium_count * 100 / count), (int)(high_count * 100 / count));
    return 1;
}

int sim_store_pending_command_json(const char *device_id, char *out, size_t size)
{
    sim_command_t command;
    if (!sim_store_pop_pending_command(device_id, &command)) return snprintf(out, size, "null");
    return snprintf(out, size,
        "{\"schema_version\":1,\"command_id\":\"%s\",\"device_id\":\"%s\",\"plant_id\":\"%s\",\"action\":\"%s\",\"duration_seconds\":%u,\"mode\":\"%s\",\"issued_at_unix_ms\":%lld,\"expires_at_unix_ms\":%lld,\"non_retained\":true}",
        command.command_id, command.device_id, command.plant_id,
        command.start ? "start" : "stop", command.duration_seconds,
        flora_mode_name(command.mode), (long long)command.issued_at_unix_ms,
        (long long)command.expires_at_unix_ms);
}
