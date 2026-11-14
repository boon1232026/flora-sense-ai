#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
import os
import ssl
import threading
import time
import urllib.request
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

BACKEND = os.environ.get("BACKEND_URL", "http://127.0.0.1:18080").rstrip("/")
AI_SERVICE_URL = os.environ.get("AI_SERVICE_URL", "http://127.0.0.1:18001").rstrip("/")
API_TOKEN = os.environ.get("FLORA_API_TOKEN", "")
DEVICE_TOKEN = os.environ.get("FLORA_DEVICE_TOKEN", "")
MQTT_HOST = os.environ.get("MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "8883"))
MQTT_USERNAME = os.environ.get("MQTT_USERNAME")
MQTT_PASSWORD = os.environ.get("MQTT_PASSWORD")
MQTT_TLS_CA_FILE = os.environ.get("MQTT_TLS_CA_FILE")
MQTT_TOPIC_PREFIX = os.environ.get("MQTT_TOPIC_PREFIX", "flora-sense-ai/a007").strip("/")
DEVICE_IDS = [item.strip() for item in os.environ.get("FLORA_DEVICE_IDS", "FLORA-ESP32-WOKWI").split(",") if item.strip()]
POLL_SECONDS = float(os.environ.get("COMMAND_POLL_SECONDS", "2"))
PLANT_CHANNELS = int(os.environ.get("WOKWI_PLANT_CHANNELS", "4"))
ANALYZED_DEVICES: dict[str, list[dict]] = {}
PUBLISHED_PLANT_CONFIGS: dict[str, str] = {}


def auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"} if token else {}


def post_backend(path: str, payload: dict, token: str = DEVICE_TOKEN) -> None:
    request = urllib.request.Request(
        BACKEND + path,
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"Content-Type": "application/json", **auth_headers(token)},
    )
    with urllib.request.urlopen(request, timeout=5):
        pass


def get_backend(path: str, token: str = DEVICE_TOKEN):
    request = urllib.request.Request(BACKEND + path, headers=auth_headers(token))
    with urllib.request.urlopen(request, timeout=5) as response:
        body = response.read()
        return json.loads(body) if body else None


def get_bytes(path: str) -> bytes:
    request = urllib.request.Request(BACKEND + path, headers=auth_headers(API_TOKEN))
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.read()


def post_ai(path: str, payload: dict):
    request = urllib.request.Request(
        AI_SERVICE_URL + path,
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read())


def iso_from_ms(value):
    if not value:
        return None
    return datetime.fromtimestamp(value / 1000, tz=timezone.utc).isoformat().replace("+00:00", "Z")


def latest_image_metrics(plant_id: str):
    images = get_backend("/v1/images", API_TOKEN) or []
    candidates = [
        image for image in images
        if image.get("plantId") == plant_id
        and image.get("status") == "ANALYZED"
        and image.get("qualityOk", True)
    ]
    if not candidates:
        return None
    latest = max(candidates, key=lambda image: int(image.get("capturedAt", 0)))
    return {
        "exg": latest.get("exg"),
        "green_ratio": latest.get("greenRatio"),
        "quality_ok": True,
    }


def sensor_history_for_plant(plant_id: str) -> list[dict]:
    readings = get_backend("/v1/readings", API_TOKEN) or []
    return [
        {
            "soil_moisture_percent": reading.get("soil_moisture"),
            "air_temperature_c": reading.get("air_temperature"),
            "air_humidity_percent": reading.get("air_humidity"),
            "leaf_temperature_c": reading.get("leaf_temperature"),
        }
        for reading in readings
        if reading.get("plantId") == plant_id
    ][-8:]


def submit_fusion(plant_id: str, history: list[dict], image_metrics=None) -> None:
    if not history:
        return
    payload = {"readings": history}
    if image_metrics:
        payload["image"] = image_metrics
    ai_result = post_ai("/v1/analyze/fusion", payload)
    features = ai_result.pop("features", {})
    post_backend("/v1/sim/ai-result", {"plant_id": plant_id, **ai_result, **features})


def run_sensor_ai(device_id: str, reading: dict, plant_id: str) -> None:
    history = ANALYZED_DEVICES.setdefault(f"{device_id}:{plant_id}", [])
    history.append(reading)
    del history[:-8]
    try:
        submit_fusion(plant_id, history, latest_image_metrics(plant_id))
    except Exception as exc:
        print(f"AI fusion error for {device_id}: {exc}")


def ensure_device_registered(device_id: str, name: str = "") -> bool:
    if device_id not in DEVICE_IDS:
        return False
    devices = get_backend("/v1/devices", API_TOKEN) or []
    if any(device.get("id") == device_id for device in devices):
        return True
    post_backend("/v1/devices", {
        "id": device_id,
        "name": name or device_id,
    }, token=API_TOKEN)
    print(f"registered connected device {device_id}")
    return True


def on_message(client, userdata, message):
    parts = message.topic.strip("/").split("/")
    try:
        devices_index = parts.index("devices")
    except ValueError:
        return
    if len(parts) != devices_index + 3:
        return
    device_id, leaf = parts[devices_index + 1], parts[devices_index + 2]
    try:
        payload = json.loads(message.payload.decode("utf-8"))
        if leaf in ("telemetry", "status") and not ensure_device_registered(device_id, payload.get("name", "")):
            raise ValueError(f"device {device_id} is not in FLORA_DEVICE_IDS")
        if leaf == "telemetry":
            metrics = payload.get("metrics", {})
            reading = {"device_id": device_id, "plant_id": payload.get("plant_id", "")}
            for source, target in (
                ("soil_moisture_percent", "soil_moisture_percent"),
                ("air_temperature_c", "air_temperature_c"),
                ("air_humidity_percent", "air_humidity_percent"),
                ("leaf_temperature_c", "leaf_temperature_c"),
            ):
                if metrics.get(source) is not None:
                    reading[target] = metrics[source]
            if not reading["plant_id"]:
                raise ValueError("telemetry missing plant_id")
            post_backend(f"/v1/devices/{device_id}/telemetry", reading)
            run_sensor_ai(device_id, reading, reading["plant_id"])
        elif leaf == "status":
            pump = payload.get("pump", {})
            network = payload.get("network", {})
            post_backend(f"/v1/devices/{device_id}/pump-status", {
                "device_id": device_id,
                "name": payload.get("name", device_id),
                "firmware_version": payload.get("firmware_version", ""),
                "ip": network.get("ip", payload.get("ip", "")),
                "battery_percent": payload.get("battery_percent", -1),
                "state": pump.get("state", "off"),
                "run_remaining_seconds": pump.get("run_remaining_seconds", 0),
            })
        elif leaf == "command_ack":
            post_backend(f"/v1/devices/{device_id}/command-ack", payload)
            print(f"ACK {device_id}: {payload}")
    except Exception as exc:
        print(f"bridge ingest error for {message.topic}: {exc}")


def publish_plant_config(client, device_id: str) -> None:
    plants = get_backend("/v1/plants", API_TOKEN) or []
    bindings = []
    for plant in plants:
        if plant.get("deviceId") != device_id:
            continue
        channel = plant.get("sensorChannel")
        if channel is None:
            channel = len(bindings)
        channel = int(channel)
        if 0 <= channel < PLANT_CHANNELS:
            bindings.append({
                "id": plant.get("id", ""),
                "name": plant.get("name", ""),
                "channel": channel,
            })
    bindings.sort(key=lambda item: item["channel"])
    payload = json.dumps({
        "schema_version": 1,
        "device_id": device_id,
        "max_channels": PLANT_CHANNELS,
        "plants": bindings,
    }, separators=(",", ":"))
    if PUBLISHED_PLANT_CONFIGS.get(device_id) == payload:
        return
    client.publish(
        f"{MQTT_TOPIC_PREFIX}/devices/{device_id}/plant_config",
        payload,
        qos=1,
        retain=True,
    )
    PUBLISHED_PLANT_CONFIGS[device_id] = payload
    print(f"published plant config to {device_id}: {len(bindings)} channel(s)")


def command_loop(client):
    while True:
        for device_id in DEVICE_IDS:
            try:
                publish_plant_config(client, device_id)
                command = get_backend(f"/v1/devices/{device_id}/commands/pending")
                if command:
                    issued_ms = command.pop("issued_at_unix_ms", None)
                    expires_ms = command.pop("expires_at_unix_ms", None)
                    issued_at = iso_from_ms(issued_ms) or datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
                    expires_at = iso_from_ms(expires_ms) or issued_at
                    expires_in = max(0, int(((expires_ms or 0) - time.time() * 1000) / 1000))
                    command.update({"issued_at": issued_at, "expires_at": expires_at, "expires_in_seconds": expires_in})
                    client.publish(f"{MQTT_TOPIC_PREFIX}/devices/{device_id}/command", json.dumps(command), qos=1, retain=False)
                    print(f"published command {command['command_id']} to {device_id}")
                task = get_backend(f"/v1/devices/{device_id}/tasks/pending")
                if task:
                    client.publish(f"{MQTT_TOPIC_PREFIX}/devices/{device_id}/task", json.dumps(task), qos=1, retain=False)
            except Exception as exc:
                print(f"command poll error for {device_id}: {exc}")
        time.sleep(POLL_SECONDS)


def image_loop():
    while True:
        try:
            images = get_backend("/v1/images", API_TOKEN) or []
            for image in images:
                if image.get("status") != "UPLOADED":
                    continue
                path = image.get("imagePath", "")
                if not path.startswith("/uploads/"):
                    continue
                data = get_bytes(path)
                metrics = post_ai("/v1/analyze/image-bytes", {
                    "dataBase64": base64.b64encode(data).decode()
                })
                post_backend("/v1/images/analysis", {
                    "id": image["id"],
                    "status": "ANALYZED",
                    "exg": metrics.get("exg"),
                    "green_ratio": metrics.get("green_ratio"),
                    "quality_ok": metrics.get("quality_ok", False),
                }, token=API_TOKEN)
                if metrics.get("quality_ok"):
                    image_metrics = {
                        "exg": metrics.get("exg"),
                        "green_ratio": metrics.get("green_ratio"),
                        "mean_rgb": metrics.get("mean_rgb"),
                        "quality_ok": True,
                    }
                    submit_fusion(image.get("plantId", ""), sensor_history_for_plant(image.get("plantId", "")), image_metrics)
                print(f"analyzed image {image['id']}")
        except Exception as exc:
            print(f"image analysis error: {exc}")
        time.sleep(POLL_SECONDS)


def main() -> int:
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    if MQTT_USERNAME:
        client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    if MQTT_PORT == 8883 or MQTT_TLS_CA_FILE:
        client.tls_set(ca_certs=MQTT_TLS_CA_FILE or None, tls_version=ssl.PROTOCOL_TLS_CLIENT)
    client.on_message = on_message
    client.connect(MQTT_HOST, MQTT_PORT, keepalive=30)
    client.subscribe(f"{MQTT_TOPIC_PREFIX}/devices/+/telemetry", qos=1)
    client.subscribe(f"{MQTT_TOPIC_PREFIX}/devices/+/status", qos=1)
    client.subscribe(f"{MQTT_TOPIC_PREFIX}/devices/+/command_ack", qos=1)
    threading.Thread(target=command_loop, args=(client,), daemon=True).start()
    threading.Thread(target=image_loop, daemon=True).start()
    print(f"MQTT bridge connected to {MQTT_HOST}:{MQTT_PORT}; topic={MQTT_TOPIC_PREFIX}; backend={BACKEND}; ai={AI_SERVICE_URL}; devices={DEVICE_IDS}")
    client.loop_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
