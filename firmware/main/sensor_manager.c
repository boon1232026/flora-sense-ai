#include "sensor_manager.h"

#include "soil_sensor.h"
#include "air_sensor.h"
#include "leaf_temperature.h"
#include "esp_timer.h"

void sensor_manager_init(void)
{
    soil_sensor_init();
    air_sensor_init();
    leaf_temperature_init();
}

flora_sensor_reading_t sensor_manager_sample(void)
{
    flora_sensor_reading_t reading = {0};
    reading.soil_moisture_percent = soil_sensor_read_percent(&reading.soil_valid);
    reading.air_temperature_c = air_sensor_read_temperature(&reading.air_valid);
    reading.air_humidity_percent = air_sensor_read_humidity(NULL);
    reading.leaf_temperature_c = leaf_temperature_read_celsius(&reading.leaf_valid);
    reading.sampled_at_unix_ms = esp_timer_get_time() / 1000;
    return reading;
}

bool sensor_manager_healthy_for_auto(const flora_sensor_reading_t *reading)
{
    return reading && reading->soil_valid && reading->air_valid && reading->leaf_valid;
}
