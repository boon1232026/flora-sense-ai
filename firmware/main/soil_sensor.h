#ifndef SOIL_SENSOR_H
#define SOIL_SENSOR_H

#include <stdbool.h>

void soil_sensor_init(void);
float soil_sensor_read_percent(bool *valid);
void soil_sensor_set_calibration(int dry_raw, int wet_raw);

#endif
