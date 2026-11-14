# FLORA SENSE AI - Wokwi ESP32-S3 simulation

This folder is a Wokwi browser project. It uses a simulated ESP32-S3 with real input components rather than generated API data:

- `soilPot1` through `soilPot4` on GPIO1/2/4/6 supply one soil-moisture channel per registered plant.
- `leafPot1` through `leafPot4` on GPIO7/8/9/10 supply a 0-8 C leaf-to-air offset per plant.
- `dht1` on GPIO15 supplies shared air temperature and humidity.
- `pumpRelay` on GPIO5 receives backend-approved start/stop commands and drives the blue pump LED.
- The backend assigns `sensorChannel` 0-3 when a plant is bound to this device. The MQTT bridge publishes that binding as retained `plant_config`; the sketch maps each channel to its real `plantId`.
- MQTT telemetry, retained status, command acknowledgements, and reboot acknowledgements use `flora-sense-ai/a007/devices/FLORA-ESP32-WOKWI/...`.

## Run

1. Start the local backend/AI/bridge path:

   ```bash
   ./scripts/run_simulator.sh
   ```

2. Open the shared Wokwi project:

   ```text
   https://wokwi.com/projects/480673814770442241
   ```

   Or create a new ESP32-S3 project at `https://wokwi.com/esp32` and copy `sketch.ino`, `diagram.json`, and `libraries.txt` into it.

3. Press Start and wait for Wi-Fi (`Wokwi-GUEST`) and MQTT (`broker.hivemq.com:1883`) to connect.

4. Register plants through the Flutter **My Plants** page. The backend assigns each plant a hardware sensor channel; the bridge publishes the real binding to Wokwi automatically.

5. Open the Flutter app. Sensor values remain empty until the Wokwi project publishes telemetry.

## Sharing with another developer

A shared Wokwi link contains only the circuit and Arduino sketch. It does not contain the local backend, AI service, bridge, or Flutter app. To run the complete system, share this repository as well.

If two people may run simulations at the same time, duplicate the Wokwi project and use unique values in `sketch.ino`:

```cpp
MQTT_TOPIC_PREFIX = "flora-sense-ai/YOUR_NAME";
DEVICE_ID = "FLORA-ESP32-WOKWI-YOUR_NAME";
```

Start the local services with matching values:

```bash
MQTT_TOPIC_PREFIX=flora-sense-ai/YOUR_NAME \
FLORA_DEVICE_ID=FLORA-ESP32-WOKWI-YOUR_NAME \
FLORA_DEVICE_IDS=FLORA-ESP32-WOKWI-YOUR_NAME \
./scripts/run_simulator.sh
```

The public HiveMQ broker is only for development simulation. For staging/production use a private authenticated MQTT endpoint and set it through environment variables; do not commit credentials.

## Data path

```text
Wokwi ESP32-S3 sensors
  -> MQTT telemetry/status
  -> infrastructure/mqtt_bridge.py
  -> C backend state/API
  -> Flutter menus

Flutter irrigation/device command
  -> C backend policy queue
  -> MQTT command/task
  -> Wokwi relay/firmware
  -> MQTT acknowledgement/status
  -> backend and UI
```

AI still does not command the pump directly. Pump commands pass through backend policy and the Wokwi firmware expiry/max-runtime checks.
