from __future__ import annotations

import base64
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from flora_ai.fusion import MODEL_VERSION, fuse
from flora_ai.image_processing import analyze_image_bytes, analyze_rgb_pixels
from flora_ai.sensor_analysis import analyze_sensor_window
from flora_ai.types import ImageMetrics, SensorSnapshot

from .schemas import (
    FusionRequest,
    FusionResponse,
    HealthResponse,
    ImageBytesRequest,
    ImageMetricsResponse,
    PixelAnalyzeRequest,
    SensorAnalyzeRequest,
)

try:
    from fastapi import FastAPI
except ImportError:  # keeps stdlib checks usable before pip install
    FastAPI = None


def _to_snapshots(request: SensorAnalyzeRequest) -> list[SensorSnapshot]:
    return [
        SensorSnapshot(
            soil_moisture_percent=r.soil_moisture_percent,
            air_temperature_c=r.air_temperature_c,
            air_humidity_percent=r.air_humidity_percent,
            leaf_temperature_c=r.leaf_temperature_c,
        )
        for r in request.readings
    ]


def create_app():
    if FastAPI is None:
        raise RuntimeError("Install ai-engine/requirements.txt before starting the API")

    app = FastAPI(title="FLORA SENSE AI Engine", version="0.1.0")

    @app.get("/healthz", response_model=HealthResponse)
    def healthz():
        return HealthResponse(status="ok", model_version=MODEL_VERSION)

    @app.post("/v1/analyze/sensors")
    def analyze_sensors(request: SensorAnalyzeRequest):
        return analyze_sensor_window(_to_snapshots(request))

    @app.post("/v1/analyze/image", response_model=ImageMetricsResponse)
    def analyze_image(request: PixelAnalyzeRequest):
        metrics = analyze_rgb_pixels(request.pixels)
        return ImageMetricsResponse(
            exg=metrics.exg,
            green_ratio=metrics.green_ratio,
            mean_rgb=list(metrics.mean_rgb) if metrics.mean_rgb else None,
            quality_ok=metrics.quality_ok,
        )

    @app.post("/v1/analyze/image-bytes", response_model=ImageMetricsResponse)
    def analyze_uploaded_image(request: ImageBytesRequest):
        try:
            image_bytes = base64.b64decode(request.dataBase64, validate=True)
            metrics = analyze_image_bytes(image_bytes)
        except ValueError:
            from fastapi import HTTPException
            raise HTTPException(status_code=422, detail="invalid_image_bytes")
        return ImageMetricsResponse(
            exg=metrics.exg,
            green_ratio=metrics.green_ratio,
            mean_rgb=list(metrics.mean_rgb) if metrics.mean_rgb else None,
            quality_ok=metrics.quality_ok,
        )

    @app.post("/v1/analyze/fusion", response_model=FusionResponse)
    def analyze_fusion(request: FusionRequest):
        metrics = analyze_sensor_window(_to_snapshots(request))
        image = None
        if request.image:
            image = ImageMetrics(
                exg=request.image.exg,
                green_ratio=request.image.green_ratio,
                mean_rgb=tuple(request.image.mean_rgb) if request.image.mean_rgb else None,
                quality_ok=request.image.quality_ok,
            )
        result = fuse(metrics, image)
        return FusionResponse(
            risk_level=result.risk_level,
            risk_score=result.risk_score,
            recommendation=result.recommendation,
            features=result.features,
            model_version=MODEL_VERSION,
        )

    return app


app = create_app() if FastAPI is not None else None
