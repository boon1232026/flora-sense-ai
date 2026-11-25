# Demo Hardware Setup — One Physical Set

This guide covers the complete bring-up of one real hardware set that replaces
the Wokwi simulator: parts list, wiring, firmware flashing, backend
configuration, and a staged bench test before field deployment.

End-to-end path for the real device:

```text
ESP32-S3 firmware → Wi-Fi → MQTT broker → infrastructure/mqtt_bridge.py
→ C backend (:18080) → Flutter app
```

> Important: the ESP-IDF firmware publishes on the fixed topic prefix
> `flora/devices/{device_id}/...`. This is **different** from the Wokwi
> prefix (`flora-sense-ai/a007`). The bridge must be started with
> `MQTT_TOPIC_PREFIX=flora` for the physical device.

## 1. Bill of materials (1 set) — รายการอุปกรณ์ 1 ชุด

| # | Part | ชื่อภาษาไทย | Qty | Notes |
|---|---|---|---:|---|
| 1 | ESP32-S3 DevKit | บอร์ด ESP32-S3 | 1 | Matches `firmware/` target |
| 2 | Capacitive soil moisture sensor (3.3 V analog) | เซนเซอร์วัดความชื้นในดินแบบ capacitive | 1 | Output must stay ≤ 3.3 V |
| 3 | SHT31 module (I²C, addr `0x44`) | เซนเซอร์วัดอุณหภูมิและความชื้นอากาศ SHT31 | 1 | Air temperature + humidity |
| 4 | MLX90614 module (I²C, addr `0x5A`) | เซนเซอร์วัดอุณหภูมิใบอินฟราเรด MLX90614 | 1 | Non-contact leaf temperature |
| 5 | DC water pump | ปั๊มน้ำ DC | 1 | Sized to irrigation line |
| 6 | Logic-level N-channel MOSFET module | โมดูลขับปั๊ม MOSFET | 1 | Flyback diode included or added |
| 7 | Pump power supply | แหล่งจ่ายไฟปั๊ม | 1 | Separate from logic supply |
| 8 | Fuse + holder | ฟิวส์ + แผงฟิวส์ | 1 | Sized to pump current |
| 9 | TEST interlock switch | สวิตช์ตัดวงจรปั๊ม (TEST interlock) | 1 | Physically cuts the pump feed |
| 10 | 5 V supply for the board | อแดปเตอร์ 5V สำหรับบอร์ด | 1 | USB adapter is fine |
| 11 | IP-rated enclosure + cable glands | กล่องกันน้ำ + ข้อต่อสายกันน้ำ | 1 | Keeps electronics dry |
| — | Breadboard, jumper wires, pull-down 10 kΩ | เบรดบอร์ด, สายจัมเปอร์, ตัวต้านทาน 10k | — | Bench prototyping |
| — | Tubing + fittings, water container | สายยาง/ท่อน้ำ + ข้อต่อ + ภาชนะใส่น้ำ | — | Pump test |

## 2. Wiring (matches `firmware` defaults) — การต่อสาย

| Signal | ESP32 GPIO | Destination | ต่ออะไร |
|---|---:|---|---|
| Soil ADC | GPIO4 | Soil sensor SIG | ขาสัญญาณเซนเซอร์ดิน |
| I²C SDA | GPIO8 | SHT31 SDA + MLX90614 SDA (shared bus) | ขา SDA ของเซนเซอร์ทั้งสอง (บัสเดียวกัน) |
| I²C SCL | GPIO9 | SHT31 SCL + MLX90614 SCL | ขา SCL ของเซนเซอร์ทั้งสอง |
| Pump gate | GPIO5 | MOSFET module IN (with ~10 kΩ pull-down to GND) | ขา IN ของโมดูลขับปั๊ม + ตัวต้านทาน 10k ลง GND |
| 3V3 | — | VCC of all three sensors | ไฟเลี้ยงเซนเซอร์ทั้ง 3 ตัว |
| GND | — | All sensor GND + MOSFET GND + pump supply (−) | กราวด์ร่วมทั้งวงจร |

Pump power path (kept separate from logic supply) — วงจรไฟเลี้ยงปั๊ม (แยกจากไฟบอร์ด):

```text
ไฟปั๊ม (+) → ฟิวส์ → สวิตช์ TEST interlock → ปั๊ม (+)
ปั๊ม (−)     → ขา Drain ของ MOSFET
ขา Source ของ MOSFET → ไฟปั๊ม (−)
ไดโอด flyback คร่อมขั้วปั๊ม (ถ้าโมดูลไม่มีในตัว)
```

```text
ESP32-S3                          เซนเซอร์
3V3 ───┬── SHT31 VIN          (เซนเซอร์อากาศ)
       ├── MLX90614 VIN       (เซนเซอร์อุณหภูมิใบ)
       └── Soil VCC           (เซนเซอร์ความชื้นดิน)
GPIO4 ── Soil SIG             (สัญญาณเซนเซอร์ดิน)
GPIO8 ──┬─ SHT31 SDA
        └─ MLX90614 SDA       (I2C บัสเดียวกัน)
GPIO9 ──┬─ SHT31 SCL
        └─ MLX90614 SCL
GPIO5 ── MOSFET IN            (ขับปั๊ม + ตัวต้านทาน 10k ลง GND)
GND ────┬─ GND เซนเซอร์ทุกตัว
        ├─ MOSFET GND
        └─ ไฟปั๊ม (−)         ← กราวด์ร่วม แต่แยกวงจรไฟเลี้ยง
```

Warnings:

- Never power the pump from the ESP32 5 V/3.3 V rail.
- Internal I²C pull-ups are enabled in firmware; add external 4.7 kΩ
  pull-ups if sensor wires exceed ~30 cm.
- Verify strapping pins on the purchased board before soldering; GPIO
  choices can be changed in `firmware/main/Kconfig.projbuild` /
  `idf.py menuconfig`.

## 3. Flash the firmware

Prerequisite: ESP-IDF installed and exported (`install.sh` + `export.sh`).

```bash
cd firmware
idf.py set-target esp32s3
idf.py menuconfig
```

Under `FLORA SENSE AI` set:

| Config | Demo value |
|---|---|
| `FLORA_WIFI_SSID` | your Wi-Fi SSID |
| `FLORA_WIFI_PASSWORD` | your Wi-Fi password |
| `FLORA_DEVICE_ID` | `FLORA-ESP32-DEV` (or your own ID) |
| `FLORA_PLANT_ID` | plant ID to bind (or register later) |
| `FLORA_MODE` | `TEST` for first bring-up |
| `FLORA_MQTT_URI` | `mqtt://broker.hivemq.com:1883` (dev only) |
| `FLORA_SOIL_ADC_GPIO` | `4` |
| `FLORA_I2C_SDA_GPIO` | `8` |
| `FLORA_I2C_SCL_GPIO` | `9` |
| `FLORA_PUMP_GPIO` | `5` |

Then:

```bash
idf.py build
idf.py -p /dev/cu.usbserial-* flash monitor
```

Expected serial output:

```text
wifi connected
mqtt connected
```

## 4. Backend + bridge for the real device

Stop the Wokwi-oriented bridge (or run it alongside on the same broker)
and start services with the firmware topic prefix and the real device ID:

```bash
python3 -m pip install -r infrastructure/requirements.txt
make -C backend all

FLORA_DEVICE_ID=FLORA-ESP32-DEV \
FLORA_STATE_FILE=./data/flora-demo-state.tsv \
./backend/build/flora-backend --serve 18080 &

python3 simulator/ai_server.py --port 18001 &

BACKEND_URL=http://127.0.0.1:18080 \
AI_SERVICE_URL=http://127.0.0.1:18001 \
MQTT_HOST=broker.hivemq.com \
MQTT_PORT=1883 \
MQTT_TOPIC_PREFIX=flora \
FLORA_DEVICE_IDS=FLORA-ESP32-DEV \
python3 infrastructure/mqtt_bridge.py &
```

Then register the plant bound to the physical device (via the app's
**My Plants** page, or API):

```bash
curl -X POST http://127.0.0.1:18080/v1/plants \
  -H 'Content-Type: application/json' \
  -d '{"name":"Demo basil","zone":"Bench","deviceId":"FLORA-ESP32-DEV","healthStatus":"LOW","soilMoisture":0}'
```

Flutter app (unchanged):

```bash
cd mobile-app
flutter run -d chrome \
  --dart-define=FLORA_API_BASE_URL=http://127.0.0.1:18080
```

## 5. Staged bench test

Run the test in this order. Keep the pump electrically disconnected
until step 4.

### Step 1 — Link up

1. Power the board. Serial shows `wifi connected` then `mqtt connected`.
2. App → **Devices**: `FLORA-ESP32-DEV` shows `ออนไลน์` with firmware
   version and IP.

### Step 2 — Sensor telemetry

1. App → **Monitoring**, select the bound plant.
2. Touch/wet the soil probe → soil % moves.
3. Breathe on the SHT31 → air temperature/humidity move.
4. Point the MLX90614 at a leaf or your hand → leaf temperature moves.
5. Devices page: Soil Moisture, DHT/SHT Air, Leaf probe all `online`.

### Step 3 — Command path without pump power

1. Leave the TEST interlock open (pump feed cut).
2. App → **Irrigation**, switch mode to MANUAL, send a 10-second start.
3. MOSFET gate should switch (LED on the module if present); pump stays
   off because the interlock physically cut the feed — this is the
   intended TEST-path behavior.
4. Devices page shows command `STARTED`/`COMPLETED` ACK with matching
   `command_id` (UUID, non-retained).

### Step 4 — Real pump run (supervised)

1. Submerge pump inlet in water, close the interlock switch.
2. Send a 10-second MANUAL start → pump runs and auto-stops.
3. Confirm the firmware hard limit: a >120 s request is capped by
   `FLORA_MAX_PUMP_RUN_MS` and the pump stops on its own.
4. Open the interlock mid-run → pump must stop immediately regardless
   of software state.
5. Switch device back to TEST mode → start requests are rejected.

### Step 5 — AUTO irrigation (optional)

1. Set thresholds in **Settings** (`autoStartMoisture`, `autoStopMoisture`).
2. Dry the soil probe → AUTO issues a bounded start when below threshold
   and stops when above the stop level.

## 6. Acceptance checklist

| Check | Where |
|---|---|
| Device `ออนไลน์`, firmware + IP visible | Devices |
| Soil/Air/Leaf sensors `online` | Devices + Monitoring |
| Readings stream every sample interval | Monitoring + Reports |
| Command ACK with UUID command_id | Devices |
| Pump stops ≤ 120 s even if network dies | Bench test |
| TEST interlock physically blocks pump | Bench test |
| Alerts appear on threshold breach | Alerts |

## 7. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Device never goes online | Wrong `FLORA_MQTT_URI`/Wi-Fi, or bridge not running |
| Telemetry rejected `UNREGISTERED_DEVICE` | `FLORA_DEVICE_ID` not in `FLORA_DEVICE_IDS` |
| `PLANT_DEVICE_MISMATCH` | Plant not bound to that device ID |
| No sensor data but device online | Bridge `MQTT_TOPIC_PREFIX` ≠ `flora` (Wokwi prefix mistake) |
| Soil value flat/stuck | Sensor not analog or wired to wrong GPIO |
| Pump never energizes | Interlock open, TEST mode, missing pull-down, or wrong gate GPIO |
| MQTT command ignored | Retained command or expired `expires_at` — firmware rejects both |

## 8. Safety reminders

- Public HiveMQ (`broker.hivemq.com`) is for development/demo only —
  use a private authenticated broker for anything permanent.
- Keep `FLORA_MODE=TEST` until the staged test above passes.
- The interlock, fuse, and flyback protection are mandatory, not
  optional, before connecting a real pump.
- See `docs/SAFETY.md` and `docs/HARDWARE_MANUAL.md` before field use.
