from __future__ import annotations

from .types import SensorMetrics, SensorSnapshot


def analyze_sensor_window(readings: list[SensorSnapshot]) -> SensorMetrics:
    valid = [r for r in readings if r.soil_moisture_percent is not None]
    if not valid:
        return SensorMetrics(None, 0.0, None, False)

    latest = valid[-1]
    if len(valid) >= 2:
        # Prototype assumes one reading per minute. Phase 06 should derive this
        # from timestamps and expose units explicitly in the response schema.
        trend = latest.soil_moisture_percent - valid[0].soil_moisture_percent
    else:
        trend = 0.0

    leaf_air_delta = None
    if latest.leaf_temperature_c is not None and latest.air_temperature_c is not None:
        leaf_air_delta = latest.leaf_temperature_c - latest.air_temperature_c

    healthy = all(
        value is not None
        for value in (
            latest.soil_moisture_percent,
            latest.air_temperature_c,
            latest.air_humidity_percent,
            latest.leaf_temperature_c,
        )
    )
    return SensorMetrics(
        soil_moisture_percent=latest.soil_moisture_percent,
        moisture_trend_per_hour=round(trend, 3),
        leaf_air_delta_c=round(leaf_air_delta, 3) if leaf_air_delta is not None else None,
        sensor_health_ok=healthy,
    )
