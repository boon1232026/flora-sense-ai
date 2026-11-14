from __future__ import annotations

from .types import FusionResult, ImageMetrics, SensorMetrics

MODEL_VERSION = "flora-rules-v1"


def clamp_score(value: float) -> int:
    return max(0, min(100, int(round(value))))


def fuse(metrics: SensorMetrics, image: ImageMetrics | None = None) -> FusionResult:
    """Deterministic baseline fusion.

    The rules intentionally weight current soil moisture, its trend and the
    leaf-air temperature delta because early water stress can precede visible
    leaf color change. Replace or combine with calibrated XGBoost outputs after
    dataset collection; retain these bounds as a fallback.
    """
    if not metrics.sensor_health_ok or metrics.soil_moisture_percent is None:
        return FusionResult(
            risk_level="MEDIUM",
            risk_score=50,
            recommendation="ตรวจสอบเซนเซอร์ก่อนประเมินความเสี่ยง ระบบยังไม่มีข้อมูลครบ",
            features={"sensor_missing": 1.0},
        )

    moisture = metrics.soil_moisture_percent
    score = 15.0
    if moisture < 25.0:
        score += 45.0
    elif moisture < 35.0:
        score += 30.0
    elif moisture < 45.0:
        score += 15.0

    if metrics.moisture_trend_per_hour < -10.0:
        score += 20.0
    elif metrics.moisture_trend_per_hour < -5.0:
        score += 10.0

    if metrics.leaf_air_delta_c is not None:
        if metrics.leaf_air_delta_c >= 4.0:
            score += 20.0
        elif metrics.leaf_air_delta_c >= 2.0:
            score += 10.0

    features = {
        "soil_moisture_percent": moisture,
        "moisture_trend_per_hour": metrics.moisture_trend_per_hour,
        "leaf_air_delta_c": metrics.leaf_air_delta_c or 0.0,
    }

    if image and image.quality_ok:
        exg = image.exg or 0.0
        green_ratio = image.green_ratio or 0.0
        features["exg"] = exg
        features["green_ratio"] = green_ratio
        if exg < 0.05 or green_ratio < 0.45:
            score += 10.0
        elif exg > 0.25 and green_ratio > 0.70:
            score -= 8.0

    score_i = clamp_score(score)
    if score_i >= 70:
        level = "HIGH"
        recommendation = "ความเสี่ยงสูง ตรวจสอบความชื้นดินและเตรียมให้น้ำตามนโยบายความปลอดภัย"
    elif score_i >= 40:
        level = "MEDIUM"
        recommendation = "ความเสี่ยงปานกลาง เฝ้าระวังแนวโน้มความชื้นและอุณหภูมิใบ"
    else:
        level = "LOW"
        recommendation = "ความเสี่ยงต่ำ ติดตามค่าตามรอบปกติ"

    return FusionResult(level, score_i, recommendation, features)
