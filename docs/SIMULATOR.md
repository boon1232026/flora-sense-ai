# Wokwi Hardware Simulation

The simulator uses a Wokwi ESP32-S3 project with physical input controls rather than a Python data generator. The browser device publishes MQTT telemetry and executes backend-approved pump commands on a simulated relay.

```text
Wokwi ESP32-S3 sensors/relay
  -> public or configured MQTT broker
  -> infrastructure/mqtt_bridge.py
  -> C backend
  -> Flutter app
```

## Run

1. Start the backend, AI service and MQTT bridge:

   ```bash
   ./scripts/run_simulator.sh
   ```

2. Open https://wokwi.com/esp32 and create an ESP32-S3 project.
3. Copy these files into the Wokwi project:
   - `wokwi/sketch.ino`
   - `wokwi/diagram.json`
   - `wokwi/libraries.txt`
4. Press **Start** in Wokwi.

Defaults:

- Backend: `http://127.0.0.1:18080`
- AI service: `http://127.0.0.1:18001`
- MQTT broker: `broker.hivemq.com:1883`
- Topic prefix: `flora-sense-ai/a007`
- Device ID: `FLORA-ESP32-WOKWI`
- Plant bindings: up to four backend-registered plants on sensor channels 0-3

Register plant/device bindings through **My Plants** or with:

```bash
curl -X POST http://127.0.0.1:18080/v1/plants \
  -H 'Content-Type: application/json' \
  -d '{"name":"ผักกาดหอม","zone":"Wokwi Bench","deviceId":"FLORA-ESP32-WOKWI","healthStatus":"LOW","soilMoisture":0}'
```

Sensor values remain empty until the Wokwi project publishes telemetry. The app uses the backend live API automatically; there is no Mock/Live switch in the production build.

## Simulated hardware controls

- `soilPot1`-`soilPot4` map GPIO1/2/4/6 to soil moisture 0-100% for channels 0-3.
- `leafPot1`-`leafPot4` map GPIO7/8/9/10 to a 0-8 C leaf-to-air offset for channels 0-3.
- `dht1` supplies shared air temperature and humidity on GPIO15.
- `pumpRelay` on GPIO5 switches the blue pump LED through a relay module.
- Irrigation commands are non-retained MQTT messages with command ID and expiry metadata.
- Plant/channel bindings are retained MQTT `plant_config` messages generated from `/v1/plants`.

## Manual checks

```bash
curl http://127.0.0.1:18080/v1/dashboard
curl http://127.0.0.1:18080/v1/readings
curl http://127.0.0.1:18080/v1/devices
curl -X POST http://127.0.0.1:18080/v1/devices/FLORA-ESP32-WOKWI/commands \
  -H 'Content-Type: application/json' \
  -d '{"plant_id":"plant-1","action":"start","duration_seconds":10}'
```

A command is accepted only while the Wokwi device is online and bound to the requested plant. The bridge publishes it to MQTT, the sketch enforces expiry/max duration, updates the relay and publishes an acknowledgement plus retained status.

## Simulator boundaries

- The public broker is suitable only for development. Use a private authenticated MQTT endpoint outside development.
- The AI service still uses `flora-rules-v1`, not a trained model.
- The pump is a relay/LED simulation; a physical pump driver and interlock still require hardware validation.
- Direct Python `simulator/virtual_device.py` is retained only as a legacy test utility and is not part of the live app path.
