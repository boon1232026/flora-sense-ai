#ifndef SENSOR_MANAGER_H
#define SENSOR_MANAGER_H

#include "flora_types.h"

void sensor_manager_init(void);
flora_sensor_reading_t sensor_manager_sample(void);
bool sensor_manager_healthy_for_auto(const flora_sensor_reading_t *reading);

#endif
