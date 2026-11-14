#include "air_sensor.h"
#include "device_config.h"
#include "device_time.h"
#include <string.h>

#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "flora_mqtt.h"
#include "nvs_flash.h"
#include "pump_controller.h"
#include "safety_controller.h"
#include "sensor_manager.h"
#include "wifi_manager.h"

#define TAG "flora_sense"

static void sampling_task(void *arg)
{
    while (true) {
        flora_sensor_reading_t reading = sensor_manager_sample();
        pump_controller_tick(reading.sampled_at_unix_ms);
        flora_mqtt_publish_telemetry(&reading);

        flora_device_status_t status = {
            .mode = safety_controller_get_mode(),
            .wifi_connected = wifi_manager_connected(),
            .mqtt_connected = flora_mqtt_client_connected(),
            .pump_state = pump_controller_state(),
            .pump_remaining_seconds = pump_controller_remaining_seconds(reading.sampled_at_unix_ms),
        };
        strlcpy(status.firmware_version, "0.1.0", sizeof(status.firmware_version));
        flora_mqtt_publish_status(&status);
        vTaskDelay(pdMS_TO_TICKS(CONFIG_FLORA_SAMPLE_INTERVAL_MS));
    }
}

void app_main(void)
{
    ESP_ERROR_CHECK(nvs_flash_init());
    device_config_load();
    safety_controller_init(device_config_mode());
    pump_controller_init();
    sensor_manager_init();
    wifi_manager_init();
    device_time_init();
    flora_mqtt_client_init();
    xTaskCreate(sampling_task, "flora_sampling", 4096, NULL, 5, NULL);
    ESP_LOGI(TAG, "FLORA SENSE AI firmware started in %s mode", flora_mode_name(safety_controller_get_mode()));
}
