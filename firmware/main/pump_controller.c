#include "pump_controller.h"

#include "driver/gpio.h"
#include "esp_log.h"

#define TAG "flora_pump"

static flora_pump_state_t s_state = FLORA_PUMP_OFF;
static int64_t s_stop_at_ms;
static uint32_t s_duration_seconds;

static void pump_output_write(bool on)
{
    gpio_set_level(CONFIG_FLORA_PUMP_GPIO, on ? 1 : 0);
}

void pump_controller_init(void)
{
    gpio_config_t config = {
        .pin_bit_mask = 1ULL << CONFIG_FLORA_PUMP_GPIO,
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_ENABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    gpio_config(&config);
    pump_output_write(false);
    s_state = FLORA_PUMP_OFF;
}

bool pump_controller_request_start(uint32_t duration_seconds)
{
    if (duration_seconds == 0 || duration_seconds > CONFIG_FLORA_MAX_PUMP_RUN_MS / 1000) {
        pump_controller_force_safe_off("duration_rejected");
        return false;
    }
    s_duration_seconds = duration_seconds;
    s_stop_at_ms = esp_timer_get_time() / 1000 + (int64_t)duration_seconds * 1000;
    pump_output_write(true);
    s_state = FLORA_PUMP_RUNNING;
    ESP_LOGI(TAG, "pump started for %lus", (unsigned long)duration_seconds);
    return true;
}

void pump_controller_request_stop(const char *reason)
{
    (void)reason;
    pump_output_write(false);
    s_state = FLORA_PUMP_OFF;
    s_stop_at_ms = 0;
}

void pump_controller_force_safe_off(const char *reason)
{
    pump_output_write(false);
    s_state = FLORA_PUMP_FAULT;
    s_stop_at_ms = 0;
    ESP_LOGW(TAG, "pump forced off: %s", reason ? reason : "unspecified");
}

void pump_controller_tick(int64_t now_unix_ms)
{
    (void)now_unix_ms;
    if (s_state == FLORA_PUMP_RUNNING && esp_timer_get_time() / 1000 >= s_stop_at_ms) {
        pump_output_write(false);
        s_state = FLORA_PUMP_OFF;
        ESP_LOGI(TAG, "pump stopped by local max-run timer");
    }
}

flora_pump_state_t pump_controller_state(void)
{
    return s_state;
}

uint32_t pump_controller_remaining_seconds(int64_t now_unix_ms)
{
    (void)now_unix_ms;
    if (s_state != FLORA_PUMP_RUNNING) {
        return 0;
    }
    int64_t remaining_ms = s_stop_at_ms - esp_timer_get_time() / 1000;
    return remaining_ms > 0 ? (uint32_t)(remaining_ms / 1000) : 0;
}
