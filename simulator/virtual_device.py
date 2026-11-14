#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import time
import urllib.error
import urllib.request
from dataclasses import dataclass

DEVICE_ID = "FLORA-ESP32-SIM"
PLANT_ID = "plant-1"


@dataclass
class VirtualDevice:
    backend: str
    ai: str
    device_token: str = ""
    soil: float = 48.0
    pump_remaining: int = 0
    tick: int = 0

    def request(self, method: str, url: str, payload: dict | None = None) -> dict | list | None:
        data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers = {"Content-Type": "application/json"}
        if self.device_token:
            headers["Authorization"] = f"Bearer {self.device_token}"
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers=headers,
        )
        try:
            with urllib.request.urlopen(request, timeout=3) as response:
                body = response.read()
                return json.loads(body) if body else None
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            print(f"[device] {method} {url} failed: {exc}")
            return None

    def sample(self) -> dict:
        self.tick += 1
        if self.pump_remaining > 0:
            self.pump_remaining -= 1
            self.soil = min(78.0, self.soil + 1.2)
            pump_state = "running" if self.pump_remaining > 0 else "off"
        else:
            self.soil = max(18.0, self.soil - 0.35)
            pump_state = "off"

        air_temperature = 31.0 + math.sin(self.tick / 12.0) * 2.0
        humidity = 62.0 - (air_temperature - 31.0) * 3.0
        leaf_temperature = air_temperature + max(0.4, (50.0 - self.soil) / 10.0)
        return {
            "device_id": DEVICE_ID,
            "plant_id": PLANT_ID,
            "soil_moisture_percent": round(self.soil, 2),
            "air_temperature_c": round(air_temperature, 2),
            "air_humidity_percent": round(max(20.0, humidity), 2),
            "leaf_temperature_c": round(leaf_temperature, 2),
            "pump_state": pump_state,
            "run_remaining_seconds": max(0, self.pump_remaining),
        }

    def poll_command(self) -> None:
        task = self.request("GET", f"{self.backend}/v1/devices/{DEVICE_ID}/tasks/pending")
        if task and task.get("action") == "reboot":
            self.pump_remaining = 0
            self.soil = 48.0
            self.tick = 0
            print("[device] reboot task acknowledged")
            self.request("POST", f"{self.backend}/v1/devices/{DEVICE_ID}/command-ack", {
                "command_id": "task-reboot",
                "status": "STARTED",
                "reason_code": "NONE",
            })
        command = self.request("GET", f"{self.backend}/v1/devices/{DEVICE_ID}/commands/pending")
        if not command:
            return
        action = command.get("action")
        duration = int(command.get("duration_seconds", 0))
        command_id = command.get("command_id", "unknown")
        if action == "start":
            self.pump_remaining = min(duration, 120)
            print(f"[device] accepted command {command_id} for {self.pump_remaining}s")
        elif action == "stop":
            self.pump_remaining = 0
            print(f"[device] accepted stop command {command_id}")
        self.request("POST", f"{self.backend}/v1/devices/{DEVICE_ID}/command-ack", {
            "command_id": command_id,
            "status": "STARTED",
            "reason_code": "NONE",
        })

    def run(self, interval: float) -> None:
        while True:
            self.poll_command()
            reading = self.sample()
            self.request("POST", f"{self.backend}/v1/sim/telemetry", reading)
            self.request("POST", f"{self.backend}/v1/sim/pump-status", {
                "device_id": DEVICE_ID,
                "state": reading["pump_state"],
                "run_remaining_seconds": reading["run_remaining_seconds"],
            })
            print(
                f"[device] soil={reading['soil_moisture_percent']}% "
                f"air={reading['air_temperature_c']}C leaf={reading['leaf_temperature_c']}C "
                f"pump={reading['pump_state']}:{reading['run_remaining_seconds']}s"
            )
            time.sleep(interval)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend", default="http://127.0.0.1:8080")
    parser.add_argument("--ai", default="http://127.0.0.1:8000")
    parser.add_argument("--interval", type=float, default=2.0)
    parser.add_argument("--device-token", default="")
    args = parser.parse_args()
    print("Virtual ESP32 started. Press Ctrl+C to stop.")
    try:
        VirtualDevice(args.backend.rstrip("/"), args.ai.rstrip("/"), args.device_token).run(args.interval)
    except KeyboardInterrupt:
        print("\nVirtual ESP32 stopped")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
