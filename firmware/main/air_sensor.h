#ifndef AIR_SENSOR_H
#define AIR_SENSOR_H

#include <stdbool.h>

void air_sensor_init(void);
float air_sensor_read_temperature(bool *valid);
float air_sensor_read_humidity(bool *valid);

#endif
