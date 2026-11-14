#ifndef LEAF_TEMPERATURE_H
#define LEAF_TEMPERATURE_H

#include <stdbool.h>

void leaf_temperature_init(void);
float leaf_temperature_read_celsius(bool *valid);

#endif
