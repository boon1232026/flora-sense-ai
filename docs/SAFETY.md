# Irrigation Safety Policy

## Modes

### TEST
- Hardware interlock disables the pump path.
- Firmware rejects every pump command, including authenticated cloud commands.
- Telemetry and AI still run.

### MANUAL
- User requests are validated by backend ownership and idempotency.
- Firmware revalidates command expiry, duration and local safety state.
- Maximum runtime is enforced on the device.

### AUTO
- AI output alone does not start irrigation.
- Require current calibrated sensor values, risk threshold, cooldown, run-time cap and device health.
- Start with AUTO disabled until plant/soil calibration exists.

## Mandatory protections

- Default-off at boot and on panic/reboot.
- No retained MQTT pump commands.
- Expired/duplicate/malformed commands cannot actuate.
- Local max-run timer is authoritative once the pump is running.
- Stop pump on sensor fault, control-task watchdog timeout, overcurrent/thermal interlock, or a physical stop input if fitted.
- Log every transition with timestamps and reason.
