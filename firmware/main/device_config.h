#ifndef DEVICE_CONFIG_H
#define DEVICE_CONFIG_H

#include "flora_types.h"

void device_config_load(void);
const char *device_config_id(void);
const char *device_config_plant_id(void);
flora_mode_t device_config_mode(void);
const char *device_config_mqtt_uri(void);
const char *device_config_mqtt_username(void);
const char *device_config_mqtt_password(void);

#endif
