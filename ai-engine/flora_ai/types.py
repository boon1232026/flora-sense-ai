from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

RiskLevel = Literal["LOW", "MEDIUM", "HIGH"]


@dataclass(frozen=True)
class SensorSnapshot:
    soil_moisture_percent: float | None
    air_temperature_c: float | None
    air_humidity_percent: float | None
    leaf_temperature_c: float | None


@dataclass(frozen=True)
class ImageMetrics:
    exg: float | None = None
    green_ratio: float | None = None
    mean_rgb: tuple[float, float, float] | None = None
    quality_ok: bool = False


@dataclass(frozen=True)
class SensorMetrics:
    soil_moisture_percent: float | None
    moisture_trend_per_hour: float
    leaf_air_delta_c: float | None
    sensor_health_ok: bool


@dataclass(frozen=True)
class FusionResult:
    risk_level: RiskLevel
    risk_score: int
    recommendation: str
    features: dict[str, float] = field(default_factory=dict)
