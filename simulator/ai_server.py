#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai-engine"))

from flora_ai.fusion import MODEL_VERSION, fuse
from flora_ai.image_processing import analyze_image_bytes
from flora_ai.sensor_analysis import analyze_sensor_window
from flora_ai.types import ImageMetrics, SensorSnapshot


class AIHandler(BaseHTTPRequestHandler):
    def _json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/healthz":
            self._json(200, {"status": "ok", "model_version": MODEL_VERSION})
        else:
            self._json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path == "/v1/analyze/image-bytes":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                payload = json.loads(self.rfile.read(length) or b"{}")
                metrics = analyze_image_bytes(base64.b64decode(payload.get("dataBase64", "")))
                self._json(200, {
                    "exg": metrics.exg,
                    "green_ratio": metrics.green_ratio,
                    "mean_rgb": list(metrics.mean_rgb) if metrics.mean_rgb else None,
                    "quality_ok": metrics.quality_ok,
                })
            except Exception as exc:
                self._json(422, {"error": "invalid_image_bytes", "detail": str(exc)})
            return
        if self.path != "/v1/analyze/fusion":
            self._json(404, {"error": "not_found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
            readings = [
                SensorSnapshot(
                    soil_moisture_percent=item.get("soil_moisture_percent"),
                    air_temperature_c=item.get("air_temperature_c"),
                    air_humidity_percent=item.get("air_humidity_percent"),
                    leaf_temperature_c=item.get("leaf_temperature_c"),
                )
                for item in payload.get("readings", [])
            ]
            if not readings:
                self._json(400, {"error": "readings_required"})
                return
            image_payload = payload.get("image")
            image = None
            if image_payload:
                image = ImageMetrics(
                    exg=image_payload.get("exg"),
                    green_ratio=image_payload.get("green_ratio"),
                    quality_ok=bool(image_payload.get("quality_ok")),
                )
            result = fuse(analyze_sensor_window(readings), image)
            self._json(200, {
                "risk_level": result.risk_level,
                "risk_score": result.risk_score,
                "recommendation": result.recommendation,
                "features": result.features,
                "model_version": MODEL_VERSION,
            })
        except Exception as exc:
            self._json(400, {"error": "invalid_request", "detail": str(exc)})

    def log_message(self, format: str, *args) -> None:
        print(f"[ai-sim] {format % args}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("0.0.0.0", args.port), AIHandler)
    print(f"AI simulator listening on http://0.0.0.0:{args.port}")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
