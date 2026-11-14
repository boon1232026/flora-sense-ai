# Hardware Manual

## Reference bill of materials

| # | Part | Reference |
|---|---|---|
| 1 | Controller | ESP32-S3 development board |
| 2 | Soil moisture | Capacitive analog sensor, ADC-compatible |
| 3 | Air sensor | SHT31, I²C |
| 4 | Leaf temperature | MLX90614, I²C |
| 5 | Camera | Smartphone or separate ESP32-CAM module |
| 6 | Pump | DC mini pump sized to plant/line |
| 7 | Driver | Logic-level N-channel MOSFET module, flyback diode |
| 8 | Power | Separate pump supply, common ground, fuse |
| 9 | Enclosure | IP-rated box and cable glands |

## Example mapping, not final PCB

| Signal | Example GPIO |
|---|---:|
| Soil ADC | GPIO4 |
| I²C SDA | GPIO8 |
| I²C SCL | GPIO9 |
| Pump driver | GPIO5 |

Confirm strapping pins, boot behavior, input-only pins and board-specific pinout before PCB or enclosure work. Prefer a pin that stays low during reset, then add a pull-down on the gate.

## Power/safety wiring

- Pump supply and logic supply must have common ground but separate power paths.
- Use a fuse sized to wiring and pump load.
- Place a flyback diode/TVS across the motor if the driver does not include suppression.
- TEST MODE must physically interrupt pump power or enable input, not merely suppress a firmware call.
- Pump default-off requires a pull-down, bounded local timer and watchdog-safe code path.
