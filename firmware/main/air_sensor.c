#include "air_sensor.h"

#include "flora_config.h"
#include "driver/i2c.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

#define TAG "air_sensor"
#define SHT31_ADDR 0x44
#define SHT31_PORT I2C_NUM_0

void air_sensor_init(void)
{
    i2c_config_t config = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = CONFIG_FLORA_I2C_SDA_GPIO,
        .scl_io_num = CONFIG_FLORA_I2C_SCL_GPIO,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = 100000,
    };
    ESP_ERROR_CHECK(i2c_param_config(SHT31_PORT, &config));
    ESP_ERROR_CHECK(i2c_driver_install(SHT31_PORT, config.mode, 0, 0, 0));
}

static bool sht31_read(float *temperature, float *humidity)
{
    uint8_t command[2] = {0x2C, 0x06};
    uint8_t data[6] = {0};
    if (i2c_master_write_to_device(SHT31_PORT, SHT31_ADDR, command, sizeof(command), pdMS_TO_TICKS(50)) != ESP_OK) {
        return false;
    }
    vTaskDelay(pdMS_TO_TICKS(20));
    if (i2c_master_read_from_device(SHT31_PORT, SHT31_ADDR, data, sizeof(data), pdMS_TO_TICKS(50)) != ESP_OK) {
        return false;
    }
    uint16_t raw_t = (data[0] << 8) | data[1];
    uint16_t raw_h = (data[3] << 8) | data[4];
    if (temperature) *temperature = -45.0f + 175.0f * (float)raw_t / 65535.0f;
    if (humidity) *humidity = 100.0f * (float)raw_h / 65535.0f;
    return true;
}

float air_sensor_read_temperature(bool *valid)
{
    float value = 0.0f;
    bool ok = sht31_read(&value, NULL);
    if (valid) *valid = ok;
    return value;
}

float air_sensor_read_humidity(bool *valid)
{
    float value = 0.0f;
    bool ok = sht31_read(NULL, &value);
    if (valid) *valid = ok;
    return value;
}
