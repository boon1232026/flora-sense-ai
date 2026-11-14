#!/usr/bin/env bash
set -euo pipefail

BACKEND_PORT="${BACKEND_PORT:-19080}"
AI_PORT="${AI_PORT:-19081}"
backend_pid=""
ai_pid=""
cleanup() {
  [[ -n "$backend_pid" ]] && kill "$backend_pid" 2>/dev/null || true
  [[ -n "$ai_pid" ]] && kill "$ai_pid" 2>/dev/null || true
}
trap cleanup EXIT

make -C backend all >/dev/null
./backend/build/flora-backend --serve "$BACKEND_PORT" &
backend_pid=$!
python3 simulator/ai_server.py --port "$AI_PORT" &
ai_pid=$!
sleep 1

BACKEND_PORT="$BACKEND_PORT" AI_PORT="$AI_PORT" python3 - <<'PY'
import json
import os
import urllib.request

backend = f"http://127.0.0.1:{os.environ['BACKEND_PORT']}"
ai = f"http://127.0.0.1:{os.environ['AI_PORT']}"

def request(method, url, payload=None):
    data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode()
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.loads(response.read() or b"null")

reading = {
    "device_id": "FLORA-ESP32-SIM",
    "plant_id": "PLANT-SIM-001",
    "soil_moisture_percent": 38.5,
    "air_temperature_c": 32.4,
    "air_humidity_percent": 62.0,
    "leaf_temperature_c": 34.1,
}
assert request("POST", f"{backend}/v1/sim/telemetry", reading)["status"] == "accepted"
result = request("POST", f"{ai}/v1/analyze/fusion", {"readings": [reading]})
assert result["risk_level"] in {"LOW", "MEDIUM", "HIGH"}
assert request("POST", f"{backend}/v1/sim/ai-result", result)["status"] == "accepted"
dashboard = request("GET", f"{backend}/v1/dashboard")
assert dashboard["latest"]["soil_moisture"] == 38.5
assert dashboard["riskScore"] == result["risk_score"]
command = request("POST", f"{backend}/v1/devices/FLORA-ESP32-SIM/commands", {
    "action": "start",
    "duration_seconds": 5,
})
assert command["status"] == "accepted"
pending = request("GET", f"{backend}/v1/devices/FLORA-ESP32-SIM/commands/pending")
assert pending["action"] == "start" and pending["duration_seconds"] == 5
assert request("POST", f"{backend}/v1/sim/pump-status", {
    "state": "running",
    "run_remaining_seconds": 5,
})["status"] == "accepted"
dashboard = request("GET", f"{backend}/v1/dashboard")
assert dashboard["pumpState"] == "running" and dashboard["pumpRemainingSeconds"] == 5
print("simulator smoke test passed")
PY
