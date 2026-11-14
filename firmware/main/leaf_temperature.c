#include "leaf_temperature.h"

#include "driver/i2c.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define MLX90614_ADDR 0x5A
#define MLX90614_PORT I2C_NUM_0
#define MLX90614_OBJECT1 0x07

void leaf_temperature_init(void)
{
}

float leaf_temperature_read_celsius(bool *valid)
{
    uint8_t command = MLX90614_OBJECT1;
    uint8_t data[3] = {0};
    bool ok = i2c_master_write_read_device(MLX90614_PORT, MLX90614_ADDR, &command, 1,
                                           data, sizeof(data), pdMS_TO_TICKS(50)) == ESP_OK;
    if (valid) *valid = ok;
    if (!ok) return 0.0f;
    uint16_t raw = ((uint16_t)data[1] << 8) | data[0];
    return (float)raw * 0.02f - 273.15f;
}
