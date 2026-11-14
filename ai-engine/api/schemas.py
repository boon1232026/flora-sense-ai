from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class SensorReadingIn(BaseModel):
    soil_moisture_percent: float | None = Field(default=None, ge=0, le=100)
    air_temperature_c: float | None = Field(default=None, ge=-40, le=100)
    air_humidity_percent: float | None = Field(default=None, ge=0, le=100)
    leaf_temperature_c: float | None = Field(default=None, ge=-40, le=125)


class SensorAnalyzeRequest(BaseModel):
    readings: list[SensorReadingIn] = Field(min_length=1)


class ImageMetricsIn(BaseModel):
    exg: float | None = None
    green_ratio: float | None = None
    mean_rgb: list[float] | None = None
    quality_ok: bool = False


class FusionRequest(SensorAnalyzeRequest):
    image: ImageMetricsIn | None = None


class FusionResponse(BaseModel):
    risk_level: Literal["LOW", "MEDIUM", "HIGH"]
    risk_score: int = Field(ge=0, le=100)
    recommendation: str
    features: dict[str, float]
    model_version: str


class PixelAnalyzeRequest(BaseModel):
    pixels: list[list[int]] = Field(min_length=1)


class ImageBytesRequest(BaseModel):
    dataBase64: str = Field(min_length=1)


class ImageMetricsResponse(BaseModel):
    exg: float | None
    green_ratio: float | None
    mean_rgb: list[float] | None
    quality_ok: bool


class HealthResponse(BaseModel):
    status: str
    model_version: str
    details: dict[str, Any] = Field(default_factory=dict)
