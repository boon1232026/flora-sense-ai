# Installation and First Run

This guide is for a developer who has just cloned or downloaded the repository and wants to run the complete local system: Flutter app, C backend, AI service, MQTT bridge, and Wokwi ESP32-S3 simulation.

## System components

- Backend API: `http://127.0.0.1:18080`
- AI service: `http://127.0.0.1:18001`
- MQTT broker for development: `broker.hivemq.com:1883`
- Default MQTT topic prefix: `flora-sense-ai/a007`
- Default Wokwi device ID: `FLORA-ESP32-WOKWI`
- Flutter web development port used in this project: `63443`

The local backend keeps simulator/app state in `data/` and uploaded images in `data/uploads`. Runtime state is intentionally not committed.

## Prerequisites

- Git
- Flutter SDK with Chrome web support
- Python 3.10+
- Host C compiler, such as Xcode Command Line Tools on macOS
- Google Chrome or another browser for Flutter web and Wokwi

Optional production services such as PostgreSQL, Supabase, and a private MQTT broker are not required for the local Wokwi simulation path.

## 1. Clone or download the project

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd FLORA_SENSE_AI
```

If the project was downloaded as a ZIP, extract it and `cd` into the project directory.

## 2. Install the Python bridge dependency

```bash
python3 -m pip install -r infrastructure/requirements.txt
```

## 3. Start backend, AI service, and MQTT bridge

```bash
./scripts/run_simulator.sh
```

Keep this terminal open. It starts:

- `backend/build/flora-backend --serve 18080`
- `simulator/ai_server.py --port 18001`
- `infrastructure/mqtt_bridge.py`

Expected startup output includes:

```text
Backend: http://127.0.0.1:18080
AI service: http://127.0.0.1:18001
MQTT bridge: broker.hivemq.com:1883/flora-sense-ai/a007
```

### Optional: use a unique device/topic

If two people run Wokwi simulations at the same time, do not share the same device ID and topic prefix. Run the local system with unique values:

```bash
MQTT_TOPIC_PREFIX=flora-sense-ai/YOUR_NAME \
FLORA_DEVICE_ID=FLORA-ESP32-WOKWI-YOUR_NAME \
FLORA_DEVICE_IDS=FLORA-ESP32-WOKWI-YOUR_NAME \
./scripts/run_simulator.sh
```

The same values must be set in `wokwi/sketch.ino` before starting the Wokwi project.

## 4. Start the Flutter app

Open a second terminal:

```bash
cd mobile-app
flutter pub get
flutter run -d chrome \
  --web-port 63443 \
  --dart-define=FLORA_API_BASE_URL=http://127.0.0.1:18080
```

Then open:

```text
http://127.0.0.1:63443/
```

For a static web build instead:

```bash
cd mobile-app
flutter build web
python3 -m http.server 63443 --directory build/web
```

## 5. Start the Wokwi ESP32-S3 simulation

The ready-to-use shared project is:

```text
https://wokwi.com/projects/480673814770442241
```

Open it and press the green **Start** button.

To create a separate Wokwi project instead, open an ESP32-S3 project and copy:

- `wokwi/sketch.ino`
- `wokwi/diagram.json`
- `wokwi/libraries.txt`

Expected serial output:

```text
WiFi connected: ...
MQTT connecting...connected
Sensor channel 0 bound to plant-1
```

If `MQTT_TOPIC_PREFIX` or `DEVICE_ID` was changed locally, update these constants in `sketch.ino` before starting Wokwi.

## 6. Verify live data flow

After Wokwi reports `MQTT connected`, wait 5-10 seconds.

```bash
curl http://127.0.0.1:18080/v1/devices
curl http://127.0.0.1:18080/v1/readings
curl http://127.0.0.1:18080/v1/dashboard
```

Expected result:

- Device becomes `online: true`
- `/v1/readings` contains plant-specific telemetry
- Dashboard `devicesOnline` becomes `1`
- Monitoring shows soil, air, humidity, and leaf values
- Irrigation can send a MANUAL pump command only after switching out of TEST mode

## Verification commands

```bash
make -C backend test
cd ai-engine && python3 -m unittest discover -s tests -v
cd mobile-app && flutter analyze && flutter test
```

ESP-IDF physical firmware checks, when the selected board and toolchain are available:

```bash
cd firmware
idf.py set-target esp32s3
idf.py build
```

## Optional production services

The local Wokwi path uses the backend's file-backed simulator state. PostgreSQL/Supabase, private MQTT TLS, real credentials, physical pump wiring, and ESP-IDF provisioning are required only for the production path. Keep real credentials in `.env`; never commit them.

## Troubleshooting

### Wokwi build fails with missing `setup()` or `loop()`

The `sketch.ino` content was not copied completely. Copy the entire `wokwi/sketch.ino` file, not only its include lines or file path.

### Wokwi diagram does not render

`diagram.json` must contain both `parts` and `connections`. Copy the complete JSON file, not only its opening or closing section.

### Device remains offline

Check that:

- Wokwi simulation is running, not only saved
- Serial Monitor shows `MQTT connecting...connected`
- `DEVICE_ID` in `sketch.ino` matches `FLORA_DEVICE_ID`/`FLORA_DEVICE_IDS`
- `MQTT_TOPIC_PREFIX` in `sketch.ino` matches the bridge environment
- `scripts/run_simulator.sh` is still running

### Device is online but there are no readings

Create a plant in **My Plants** and bind it to the Wokwi device. The backend assigns a `sensorChannel`; the bridge publishes it as retained `plant_config`; Wokwi maps that channel to a real potentiometer input.

### Pump does not start

- `TEST` mode intentionally blocks pump output
- Device must be online
- The selected plant must be bound to the device
- Pump must be enabled in Settings
- Command must be within duration and safety limits
