#include "device_config.h"

#include <string.h>

#define STR_VALUE(value) #value
#define STR_MACRO(value) STR_VALUE(value)

#ifndef CONFIG_FLORA_DEVICE_ID
#define CONFIG_FLORA_DEVICE_ID "FLORA-ESP32-DEV"
#endif
#ifndef CONFIG_FLORA_PLANT_ID
#define CONFIG_FLORA_PLANT_ID "PLANT-DEV"
#endif
#ifndef CONFIG_FLORA_MQTT_URI
#define CONFIG_FLORA_MQTT_URI "mqtts://localhost:8883"
#endif
#ifndef CONFIG_FLORA_MQTT_USERNAME
#define CONFIG_FLORA_MQTT_USERNAME ""
#endif
#ifndef CONFIG_FLORA_MQTT_PASSWORD
#define CONFIG_FLORA_MQTT_PASSWORD ""
#endif
#ifndef CONFIG_FLORA_MODE
#define CONFIG_FLORA_MODE TEST
#endif

static flora_mode_t parse_mode(void)
{
    if (strcmp(STR_MACRO(CONFIG_FLORA_MODE), "MANUAL") == 0) return FLORA_MODE_MANUAL;
    if (strcmp(STR_MACRO(CONFIG_FLORA_MODE), "AUTO") == 0) return FLORA_MODE_AUTO;
    return FLORA_MODE_TEST;
}

void device_config_load(void)
{
}

const char *device_config_id(void) { return CONFIG_FLORA_DEVICE_ID; }
const char *device_config_plant_id(void) { return CONFIG_FLORA_PLANT_ID; }
flora_mode_t device_config_mode(void) { return parse_mode(); }
const char *device_config_mqtt_uri(void) { return CONFIG_FLORA_MQTT_URI; }
const char *device_config_mqtt_username(void) { return CONFIG_FLORA_MQTT_USERNAME; }
const char *device_config_mqtt_password(void) { return CONFIG_FLORA_MQTT_PASSWORD; }
