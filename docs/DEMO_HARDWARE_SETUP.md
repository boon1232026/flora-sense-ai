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

ชุด demo นี้สั่งจาก CyberTice + ใช้ของที่มีในชุด kit (ไม่ใช้บอร์ดฐาน
ขยาย — ต่อผ่าน breadboard แทน):

| รหัสสินค้า | Part | ชื่อภาษาไทย | Qty | ใช้ทำอะไร |
|---|---|---|---:|---|
| M1622 | ESP32-S3 core board N16R8 (DevKitC-1 compatible, USB-C) | บอร์ด ESP32-S3 | 1 | สมองของระบบ รัน `firmware/` |
| M0409 | Capacitive Soil Moisture Sensor (3.3–5 V analog) | เซนเซอร์ความชื้นดิน capacitive | 1 | ความชื้นดิน → GPIO4 ADC |
| M1657 | SHT31 module สีแดง (I²C `0x44`) | เซนเซอร์อากาศ SHT31 | 1 | อุณหภูมิ+ความชื้นอากาศ |
| M0111 | GY-906-BAA MLX90614ESF (I²C `0x5A`, ~5 cm) | เซนเซอร์อุณหภูมิใบ IR | 1 | อุณหภูมิใบแบบไม่สัมผัส |
| M1270 | MOSFET + Optocoupler module 5–36 V 5 A | โมดูลขับปั๊ม (มี opto) | 1 | ขับปั๊มจาก GPIO5 แยกสัญญาณ |
| PJ005 | Starter kit mini (breadboard + jumpers + ฯลฯ) | ชุด breadboard + สายจัมเปอร์ | 1 | ที่ต่อรวมวงจรทั้งหมด |
| PJ022 | Automatic watering DIY set | ชุดปั๊ม+ท่อ+ภาชนะ | 1 | ปั๊มจิ๋ว 3–6 V + ท่อ + กล่องน้ำ |

ของที่มีอยู่แล้ว / หาเอง:

| Item | ชื่อภาษาไทย | หมายเหตุ |
|---|---|---|
| USB-C cable (computer port) | สาย USB-C | ไฟเลี้ยงบอร์ด + flash + serial monitor เส้นเดียว |
| USB cable #2 or phone charger 5 V | สาย USB เส้นที่ 2 / ที่ชาร์จมือถือ | **ไฟเลี้ยงปั๊มแยก** — ตัดปลายสายเอาแดง/ดำเข้า terminal |

ของที่ BOM ก่อนหน้าระบุไว้แต่ชุด demo นี้ข้ามได้:

- **บอร์ดฐานขยาย (M1692)** — ใช้ breadboard ใน PJ005 แทน
- **ฟิวส์** — ไฟปั๊มมาจาก USB ซึ่งจำกัดกระแสในตัวอยู่แล้ว (ต้องมีเมื่อย้ายไป
  adapter/แบตเตอรี่หรือติดตั้งจริง)
- **สวิตช์ interlock** — ใช้วิธีถอด/เสียบสายไฟปั๊มแทน (ดู §5)
- **อแดปเตอร์ 5 V บอร์ด** — USB คอมจ่ายอยู่แล้ว
- **กล่องกันน้ำ** — ใช้ตอนติดตั้งกลางแจ้งจริงเท่านั้น
- **ตัวต้านทาน pull-down 10 kΩ** — M1270 มีวงจรอินพุต opto ในตัว
- เซนเซอร์ดิน resistive + relay ใน PJ022 — อะไหล่สำรอง ไม่ได้ใช้ใน wiring หลัก

## 2. Assembly + wiring (matches `firmware` defaults) — การประกอบและต่อสาย

GPIO ทั้งหมดตรงกับค่า default ใน `firmware/main/flora_config.h` —
ไม่ต้องแก้โค้ด:

| Signal | ESP32 GPIO | Destination | ต่ออะไร |
|---|---|---:|---|
| Soil ADC | GPIO4 | Soil sensor AO | ขาสัญญาณ analog เซนเซอร์ดิน |
| I²C SDA | GPIO8 | SHT31 SDA + MLX90614 SDA | บัสเดียวกัน รวมใน breadboard |
| I²C SCL | GPIO9 | SHT31 SCL + MLX90614 SCL | บัสเดียวกัน รวมใน breadboard |
| Pump trigger | GPIO5 | M1270 ขา IN (ฝั่งสัญญาณ) | จุด LED opto สั่งปั๊ม |
| 3V3 | — | VIN เซนเซอร์ทั้ง 3 ตัว | ไฟเลี้ยงเซนเซอร์ |
| GND | — | GND เซนเซอร์ทุกตัว + GND ฝั่งสัญญาณ M1270 | กราวด์ร่วมฝั่ง logic |

### ขั้นตอนประกอบ (breadboard)

1. **เสียบบอร์ด N16R8 ลง breadboard** — ขาสองข้างคร่อมร่องกลางของแผ่น
   (ถ้าบอร์ดกว้างจนเสียบไม่ลง ให้วางข้างแผ่นแล้วใช้สายจัมเปอร์เมีย-เมีย
   จากขาบอร์ดเข้าแถว breadboard แทน)
2. **ทำรางไฟ** — เสียบจัมเปอร์จากขา `3V3` ของบอร์ดเข้าราง (+) และ `GND`
   เข้าราง (−) ของ breadboard
3. **เซนเซอร์ดิน (M0409)** — 3 เส้น: `VCC→ราง 3V3`, `GND→ราง GND`,
   `AO→แถวเดียวกับขา GPIO4`
4. **บัส I²C รวมสองเซนเซอร์** — เสียบ SHT31 (M1657) และ MLX90614 (M0111)
   ลง breadboard คนละบล็อกแถว แล้ว:
   - จัมเปอร์ `GPIO8` → แถวรวม SDA → แตะ SDA ของทั้งสองโมดูล
   - จัมเปอร์ `GPIO9` → แถวรวม SCL → แตะ SCL ของทั้งสองโมดูล
   - `VIN→3V3`, `GND→GND` ทั้งคู่
   - address ต่างกัน (SHT31=`0x44`, MLX90614=`0x5A`) แชร์บัสได้ปลอดภัย
5. **M1270 ฝั่งสัญญาณ** — `GPIO5→IN`, `GND→GND` ของขั้วสัญญาณ
   (active-high: GPIO ขึ้น HIGH = opto จุด = ปั๊มติด ตรงกับ firmware)
6. **M1270 ฝั่งโหลด (วงจรปั๊ม แยกไฟ)** — เดินสายผ่านขั้ว terminal ของโมดูล
   ตามผังด้านล่าง สาย USB เส้นที่ 2 ตัดปลาย: แดง=+5V ดำ=GND

Pump power path (แยกจากไฟบอร์ดเด็ดขาด):

```text
สาย USB เส้นที่ 2 (แดง +5V) ──► M1270 ขั้วโหลด IN+
สาย USB เส้นที่ 2 (ดำ GND)  ──► M1270 ขั้วโหลด IN−
ปั๊ม (+)                    ──► M1270 ขั้วโหลด OUT+
ปั๊ม (−)                    ──► M1270 ขั้วโหลด OUT−
```

ตำแหน่งขั้ว +/− ฝั่งโหลดอาจต่างกันเล็กน้อยตามล็อตโมดูล — ดู silkscreen
บนแผ่น (ฝั่ง terminal ใหญ่) แล้วต่อตามขั้วที่ระบุ

```text
[USB คอม #1] ──USB-C──► ESP32-S3 N16R8 เสียบ breadboard
                          │ 3V3 ──► ราง+ ──► VIN เซนเซอร์ ×3
                          │ GND ──► ราง− ──► GND เซนเซอร์ ×3 + M1270 GND(สัญญาณ)
                          │ GPIO4 ──────────► Soil AO
                          │ GPIO8 ──► แถวรวม SDA ──► SHT31.SDA + MLX.SDA
                          │ GPIO9 ──► แถวรวม SCL ──► SHT31.SCL + MLX.SCL
                          │ GPIO5 ──────────► M1270 IN (ฝั่งสัญญาณ)

[USB #2/ชาร์จ 5V] ──(แดง)──► M1270 IN+ ┐
                    ──(ดำ)──► M1270 IN− │ ฝั่งโหลด แยกไฟจากบอร์ด
         ปั๊ม(+) ─────────► M1270 OUT+ │
         ปั๊ม(−) ─────────► M1270 OUT− ┘
```

Warnings:

- **ห้ามจ่ายไฟปั๊มผ่านขา 5V/3V3 ของบอร์ดเด็ดขาด** — ไฟปั๊มวิ่งผ่านขั้ว
  terminal ของ M1270 เท่านั้น
- TEST interlock ของชุดนี้คือ **สาย USB เส้นที่ 2** — ยังไม่เสียบ =
  วงจรปั๊มตัดสนิท ใช้แทนสวิตช์ในขั้นเทส (§5)
- Internal I²C pull-ups เปิดใน firmware แล้ว สายเซนเซอร์สั้นบน
  breadboard ไม่ต้องต่อ R เพิ่ม
- MLX90614 หันกระบอก IR เข้าหาใบ ระยะ ~2–5 cm อย่าให้โดนแดดตรง
- เซนเซอร์ดินเสียบลึกแค่เส้นขีดบนแผ่น (ส่วนอิเล็กทรอนิกส์ต้องพ้นดิน)
- GPIO เปลี่ยนได้ใน `idf.py menuconfig` ถ้าบอร์ดจริงมีปัญหากับขาใดขาหนึ่ง


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

1. ยังไม่เสียบสาย USB เส้นที่ 2 (ไฟเลี้ยงปั๊ม) — วงจรปั๊มตัดสนิท
2. App → **Irrigation**, switch mode to MANUAL, send a 10-second start.
3. M1270 signal side should switch (opto LED on the module lights);
   pump stays off because its power feed is physically unplugged —
   this is the intended TEST-path behavior.
4. Devices page shows command `STARTED`/`COMPLETED` ACK with matching
   `command_id` (UUID, non-retained).

### Step 4 — Real pump run (supervised)

1. Submerge pump inlet in water, plug in USB cable #2 (pump feed).
2. Send a 10-second MANUAL start → pump runs and auto-stops.
3. Confirm the firmware hard limit: a >120 s request is capped by
   `FLORA_MAX_PUMP_RUN_MS` and the pump stops on its own.
4. ดึงสาย USB #2 ออกกลางรัน → ปั๊มต้องดับทันทีโดยไม่สนสถานะซอฟต์แวร์
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
| ถอดสายไฟปั๊มแล้วปั๊มดับทันที (physical cut) | Bench test |
| Alerts appear on threshold breach | Alerts |

## 7. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Device never goes online | Wrong `FLORA_MQTT_URI`/Wi-Fi, or bridge not running |
| Telemetry rejected `UNREGISTERED_DEVICE` | `FLORA_DEVICE_ID` not in `FLORA_DEVICE_IDS` |
| `PLANT_DEVICE_MISMATCH` | Plant not bound to that device ID |
| No sensor data but device online | Bridge `MQTT_TOPIC_PREFIX` ≠ `flora` (Wokwi prefix mistake) |
| Soil value flat/stuck | Sensor not analog or wired to wrong GPIO |
| Pump never energizes | USB #2 not plugged, TEST mode, wrong IN wiring, or wrong GPIO5 |
| MQTT command ignored | Retained command or expired `expires_at` — firmware rejects both |

## 8. Safety reminders

- Public HiveMQ (`broker.hivemq.com`) is for development/demo only —
  use a private authenticated broker for anything permanent.
- Keep `FLORA_MODE=TEST` until the staged test above passes.
- ชุด bench นี้ใช้การถอดสาย USB ปั๊มเป็น interlock — เมื่อย้ายไป
  adapter/แบตเตอรี่หรือติดตั้งจริง **ต้องมี** ฟิวส์ + สวิตช์ interlock
  + flyback protection ครบ
- See `docs/SAFETY.md` and `docs/HARDWARE_MANUAL.md` before field use.
