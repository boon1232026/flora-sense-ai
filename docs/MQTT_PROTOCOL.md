# MQTT Protocol

## Topic namespace

```text
flora/devices/{device_id}/telemetry      QoS1, non-retained
flora/devices/{device_id}/status         QoS1, retained status snapshot
flora/devices/{device_id}/heartbeat      QoS0, non-retained
flora/devices/{device_id}/command        QoS1, non-retained
flora/devices/{device_id}/command_ack    QoS1, non-retained
flora/plants/{plant_id}/image_event      QoS1, non-retained
flora/plants/{plant_id}/ai_result        QoS1, non-retained
flora/plants/{plant_id}/alert            QoS1, non-retained
```

## Command rules

- Include a UUID `command_id`, `issued_at`, `expires_at`, `mode`, `action` and bounded `duration_seconds`.
- Set `non_retained=true` and reject retained command deliveries on the device.
- Firmware stores recent IDs in bounded non-volatile/replay state and emits `DUPLICATE` for a repeated ID.
- Expired commands are rejected with `EXPIRED`; they are never queued for later execution.
- Unknown topics, malformed JSON, wrong device IDs or unauthenticated sources are rejected/logged without pump output.
- Telemetry may be buffered when offline only if bounded by memory and marked with the original sample time.

## Payload schemas

Canonical payloads are versioned under `contracts/mqtt/`:

- `telemetry.schema.json`
- `device-status.schema.json`
- `pump-command.schema.json`
- `pump-command-ack.schema.json`
- `ai-result.schema.json`
- `alert.schema.json`

All timestamps are ISO 8601 UTC. Numeric values use SI units unless the schema says otherwise.
