#include "soil_sensor.h"

#include "flora_config.h"
#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_log.h"

#define TAG "soil_sensor"

static adc_oneshot_unit_handle_t s_adc;
static int s_dry_raw = 3000;
static int s_wet_raw = 1200;

void soil_sensor_init(void)
{
    adc_oneshot_unit_init_cfg_t init_config = {.unit_id = ADC_UNIT_1};
    ESP_ERROR_CHECK(adc_oneshot_new_unit(&init_config, &s_adc));

    adc_channel_t channel = ADC_CHANNEL_0;
    if (CONFIG_FLORA_SOIL_ADC_GPIO == 4) {
        channel = ADC_CHANNEL_3;
    } else if (CONFIG_FLORA_SOIL_ADC_GPIO == 2) {
        channel = ADC_CHANNEL_1;
    }

    adc_oneshot_chan_cfg_t channel_config = {
        .atten = ADC_ATTEN_DB_12,
        .bitwidth = ADC_BITWIDTH_12,
    };
    ESP_ERROR_CHECK(adc_oneshot_config_channel(s_adc, channel, &channel_config));
}

float soil_sensor_read_percent(bool *valid)
{
    int raw = 0;
    if (adc_oneshot_read(s_adc, CONFIG_FLORA_SOIL_ADC_GPIO == 4 ? ADC_CHANNEL_3 : ADC_CHANNEL_1, &raw) != ESP_OK) {
        if (valid) *valid = false;
        return 0.0f;
    }
    if (valid) *valid = true;
    int span = s_dry_raw - s_wet_raw;
    if (span <= 0) {
        if (valid) *valid = false;
        return 0.0f;
    }
    float percent = 100.0f * (float)(s_dry_raw - raw) / (float)span;
    if (percent < 0.0f) percent = 0.0f;
    if (percent > 100.0f) percent = 100.0f;
    return percent;
}

void soil_sensor_set_calibration(int dry_raw, int wet_raw)
{
    if (dry_raw > wet_raw) {
        s_dry_raw = dry_raw;
        s_wet_raw = wet_raw;
    }
}
