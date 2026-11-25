# FLORA SENSE AI

Intelligent Plant Health Monitoring & Early Water Stress Detection System

ระบบต้นแบบสำหรับตรวจวัดสุขภาพพืช ตรวจจับความเครียดจากการขาดน้ำระยะเริ่มต้น และควบคุมการให้น้ำอย่างปลอดภัยผ่าน ESP32-S3, MQTT, C backend, PostgreSQL/Supabase, Python AI และ Flutter

## Monorepo

- `firmware/` — ESP32-S3 / ESP-IDF source modules
- `backend/` — C backend, device commands, MQTT/API adapters
- `ai-engine/` — Python image analysis, sensor analysis, fusion model, API
- `mobile-app/` — Flutter Android/iOS/Web application
- `database/` — PostgreSQL schema, policies, migrations
- `contracts/` — JSON Schema and OpenAPI service contracts
- `infrastructure/` — Docker, EMQX, deployment configuration
- `hardware/` — wiring notes, schematic/PCB placeholders, BOM
- `docs/` — architecture, installation, protocol, safety, user documentation

## Control principle

`Monitor → Analyze → Predict → Alert → Respond`

The pump remains fail-closed. TEST MODE blocks actuator output at the software and hardware-interlock layers. Cloud commands are validated for ownership, expiry, duplicate IDs, mode and safety policy before reaching the device.

## Quick start after cloning

```bash
python3 -m pip install -r infrastructure/requirements.txt
./scripts/run_simulator.sh
```

Run Flutter in another terminal:

```bash
cd mobile-app
flutter pub get
flutter run -d chrome \
  --web-port 63443 \
  --dart-define=FLORA_API_BASE_URL=http://127.0.0.1:18080
```

Then start the Wokwi ESP32-S3 project at `https://wokwi.com/projects/480673814770442241` or copy the files under `wokwi/` into a new Wokwi project.

Complete first-run, sharing, and troubleshooting instructions are in `docs/INSTALLATION.md` and `docs/SIMULATOR.md`. For one physical hardware set (parts, wiring, flashing, staged bench test), see `docs/DEMO_HARDWARE_SETUP.md`.

## Development entry points

```bash
# Backend unit-test build using the host C compiler
make -C backend test

# AI engine checks
cd ai-engine && python3 -m unittest discover -s tests -v

# Flutter checks
cd mobile-app && flutter analyze && flutter test

# ESP-IDF build, after ESP-IDF is installed and exported
cd firmware && idf.py set-target esp32s3 && idf.py build
```

`backend/CMakeLists.txt` is also included for toolchains that prefer CMake, but this workspace currently has no `cmake` executable installed, so `backend/Makefile` is the verified local path.

## Configuration

Copy `.env.example` to `.env` for local development. Do not commit real Supabase keys, EMQX credentials, device certificates or database passwords.

## Initial safety boundary

Before attaching a pump or mains/high-current supply, read `docs/HARDWARE_MANUAL.md` and `docs/SAFETY.md`. Example GPIO assignments are compile-time defaults only; verify the board pinout, transistor rating, flyback diode, fusing and physical TEST interlock against the actual hardware.
