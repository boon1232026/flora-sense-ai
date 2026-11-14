#!/usr/bin/env bash
set -euo pipefail

make -C backend all >/dev/null

backend_pid=""
ai_pid=""
bridge_pid=""
cleanup() {
  [[ -n "$bridge_pid" ]] && kill "$bridge_pid" 2>/dev/null || true
  [[ -n "$ai_pid" ]] && kill "$ai_pid" 2>/dev/null || true
  [[ -n "$backend_pid" ]] && kill "$backend_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

FLORA_DEVICE_ID="${FLORA_DEVICE_ID:-FLORA-ESP32-WOKWI}" \
FLORA_STATE_FILE="${FLORA_STATE_FILE:-data/flora-wokwi-state.tsv}" \
./backend/build/flora-backend --serve "${BACKEND_PORT:-18080}" &
backend_pid=$!
python3 simulator/ai_server.py --port "${AI_PORT:-18001}" &
ai_pid=$!

BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:${BACKEND_PORT:-18080}}" \
AI_SERVICE_URL="${AI_SERVICE_URL:-http://127.0.0.1:${AI_PORT:-18001}}" \
MQTT_HOST="${MQTT_HOST:-broker.hivemq.com}" \
MQTT_PORT="${MQTT_PORT:-1883}" \
MQTT_TOPIC_PREFIX="${MQTT_TOPIC_PREFIX:-flora-sense-ai/a007}" \
FLORA_DEVICE_IDS="${FLORA_DEVICE_IDS:-FLORA-ESP32-WOKWI}" \
FLORA_API_TOKEN="${FLORA_API_TOKEN:-}" \
FLORA_DEVICE_TOKEN="${FLORA_DEVICE_TOKEN:-}" \
python3 -u infrastructure/mqtt_bridge.py &
bridge_pid=$!

sleep 1
echo "Backend: http://127.0.0.1:${BACKEND_PORT:-18080}"
echo "AI service: http://127.0.0.1:${AI_PORT:-18001}"
echo "MQTT bridge: ${MQTT_HOST:-broker.hivemq.com}:${MQTT_PORT:-1883}/${MQTT_TOPIC_PREFIX:-flora-sense-ai/a007}"
echo "Wokwi project files: wokwi/"
echo "Flutter: flutter run -d macos --dart-define=FLORA_API_BASE_URL=http://127.0.0.1:${BACKEND_PORT:-18080}"
echo "Web: flutter run -d chrome --dart-define=FLORA_API_BASE_URL=http://127.0.0.1:${BACKEND_PORT:-18080}"
wait "$bridge_pid"
