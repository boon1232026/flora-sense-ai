#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
import os
import time
import urllib.request

BACKEND = os.environ.get("BACKEND_URL", "http://127.0.0.1:18080").rstrip("/")
AI_SERVICE_URL = os.environ.get("AI_SERVICE_URL", "http://127.0.0.1:18001").rstrip("/")
API_TOKEN = os.environ.get("FLORA_API_TOKEN", "")
POLL_SECONDS = float(os.environ.get("IMAGE_POLL_SECONDS", "3"))


def headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {API_TOKEN}"} if API_TOKEN else {}


def request_json(method: str, url: str, payload: dict | None = None):
    request = urllib.request.Request(
        url,
        data=None if payload is None else json.dumps(payload).encode(),
        method=method,
        headers={"Content-Type": "application/json", **headers()},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        body = response.read()
        return json.loads(body) if body else None


def get_upload(path: str) -> bytes:
    request = urllib.request.Request(BACKEND + path, headers=headers())
    with urllib.request.urlopen(request, timeout=15) as response:
        return response.read()


def analyze_pending_images() -> None:
    images = request_json("GET", f"{BACKEND}/v1/images") or []
    for image in images:
        if image.get("status") != "UPLOADED" or not image.get("imagePath", "").startswith("/uploads/"):
            continue
        data = get_upload(image["imagePath"])
        metrics = request_json("POST", f"{AI_SERVICE_URL}/v1/analyze/image-bytes", {
            "dataBase64": base64.b64encode(data).decode()
        })
        request_json("POST", f"{BACKEND}/v1/images/analysis", {
            "id": image["id"],
            "status": "ANALYZED",
            "exg": metrics.get("exg"),
            "green_ratio": metrics.get("green_ratio"),
            "quality_ok": metrics.get("quality_ok", False),
        })
        print(f"[image-worker] analyzed {image['id']}")


def main() -> int:
    print(f"[image-worker] backend={BACKEND} ai={AI_SERVICE_URL}")
    while True:
        try:
            analyze_pending_images()
        except Exception as exc:
            print(f"[image-worker] {exc}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
