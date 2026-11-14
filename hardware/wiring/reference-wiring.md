# Reference Wiring

This document is a prototype wiring map, not final fabrication output.

| Function | ESP32 example | External hardware |
|---|---:|---|
| Soil ADC | GPIO4 | Sensor analog out, powered at ESP32-safe voltage |
| I²C SDA | GPIO8 | SHT31 SDA and MLX90614 SDA |
| I²C SCL | GPIO9 | SHT31 SCL and MLX90614 SCL |
| Pump gate | GPIO5 | Logic-level MOSFET gate input through pull-down |
| Ground | GND | Shared ground to pump supply negative |

The pump supply positive goes through fuse, TEST interlock and driver drain path to the pump. The pump negative returns to pump supply negative. Add a flyback diode across the motor unless the driver already includes suppression.

Do not power the pump from the ESP32 5V/3.3V rail. Do not treat the GPIO list as final until the selected board's strapping pins and ADC channels are verified.
