#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import time
import urllib.request
from collections import defaultdict

BACKEND = os.environ.get("BACKEND_URL", "http://127.0.0.1:18080").rstrip("/")
AI_SERVICE_URL = os.environ.get("AI_SERVICE_URL", "http://127.0.0.1:18001").rstrip("/")
API_TOKEN = os.environ.get("FLORA_API_TOKEN", "")
DEVICE_TOKEN = os.environ.get("FLORA_DEVICE_TOKEN", "")
POLL_SECONDS = float(os.environ.get("TELEMETRY_AI_POLL_SECONDS", "2"))
last_analyzed_by_plant: dict[str, int] = defaultdict(int)


def headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"} if token else {}


def request_json(method: str, url: str, payload: dict | None = None, token: str = ""):
    request = urllib.request.Request(
        url,
        data=None if payload is None else json.dumps(payload).encode(),
        method=method,
        headers={"Content-Type": "application/json", **headers(token)},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        body = response.read()
        return json.loads(body) if body else None


def image_metrics_by_plant() -> dict[str, dict]:
    images = request_json("GET", f"{BACKEND}/v1/images", token=API_TOKEN) or []
    metrics: dict[str, dict] = {}
    for image in images:
        if image.get("status") != "ANALYZED" or not image.get("qualityOk", True):
            continue
        plant_id = image.get("plantId") or image.get("plant_id")
        if not plant_id:
            continue
        metrics[plant_id] = {
            "exg": image.get("exg"),
            "green_ratio": image.get("greenRatio"),
            "quality_ok": True,
        }
    return metrics


def analyze_latest() -> None:
    readings = request_json("GET", f"{BACKEND}/v1/readings", token=API_TOKEN) or []
    if not readings:
        return
    image_metrics = image_metrics_by_plant()

    by_plant: dict[str, list[dict]] = defaultdict(list)
    for item in readings[-32:]:
        plant_id = item.get("plantId") or item.get("plant_id") or "plant-1"
        by_plant[plant_id].append(item)

    for plant_id, plant_readings in by_plant.items():
        latest = plant_readings[-1]
        sampled_at = int(latest.get("sampled_at_unix_ms", 0))
        if sampled_at <= last_analyzed_by_plant[plant_id]:
            continue
        window = [
            {
                "soil_moisture_percent": item.get("soil_moisture"),
                "air_temperature_c": item.get("air_temperature"),
                "air_humidity_percent": item.get("air_humidity"),
                "leaf_temperature_c": item.get("leaf_temperature"),
            }
            for item in plant_readings[-8:]
        ]
        payload = {"readings": window}
        if plant_id in image_metrics:
            payload["image"] = image_metrics[plant_id]
        result = request_json("POST", f"{AI_SERVICE_URL}/v1/analyze/fusion", payload)
        features = result.pop("features", {})
        request_json("POST", f"{BACKEND}/v1/sim/ai-result", {
            "plant_id": plant_id,
            **result,
            **features,
        }, token=DEVICE_TOKEN)
        last_analyzed_by_plant[plant_id] = sampled_at
        print(f"[telemetry-ai] {plant_id} {sampled_at}: {result.get('risk_level')} {result.get('risk_score')}")


def main() -> int:
    print(f"[telemetry-ai] backend={BACKEND} ai={AI_SERVICE_URL}")
    while True:
        try:
            analyze_latest()
        except Exception as exc:
            print(f"[telemetry-ai] {exc}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
