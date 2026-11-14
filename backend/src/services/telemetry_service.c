#include "telemetry_service.h"

static bool in_range(double value, double min, double max)
{
    return value >= min && value <= max;
}

bool telemetry_service_validate(const flora_telemetry_t *reading)
{
    if (!reading || reading->sampled_at_unix_ms <= 0) return false;
    if (reading->soil_valid && !in_range(reading->soil_moisture, 0.0, 100.0)) return false;
    if (reading->air_valid && !in_range(reading->air_temperature, -40.0, 100.0)) return false;
    if (reading->air_valid && !in_range(reading->air_humidity, 0.0, 100.0)) return false;
    if (reading->leaf_valid && !in_range(reading->leaf_temperature, -40.0, 125.0)) return false;
    return true;
}
