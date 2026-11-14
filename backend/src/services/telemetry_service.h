#ifndef TELEMETRY_SERVICE_H
#define TELEMETRY_SERVICE_H

#include "../core/types.h"

typedef struct {
    double soil_moisture;
    double air_temperature;
    double air_humidity;
    double leaf_temperature;
    bool soil_valid;
    bool air_valid;
    bool leaf_valid;
    int64_t sampled_at_unix_ms;
} flora_telemetry_t;

bool telemetry_service_validate(const flora_telemetry_t *reading);

#endif
