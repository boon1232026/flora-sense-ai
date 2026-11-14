# System Architecture

## Components

1. **ESP32-S3 firmware** — acquisition, calibration, offline safety, MQTT telemetry, command ACK, pump actuation.
2. **EMQX Cloud** — authenticated device messaging and command routing. Use one credential set per physical device and topic ACLs.
3. **C backend** — MQTT ingestion, REST API, command authorization, device state, persistence and orchestration.
4. **PostgreSQL/Supabase** — relational data, audit history, auth linkage, object-path metadata and realtime notifications.
5. **Python AI service** — image features, sensor trends, feature fusion and recommendation. It returns risk decisions but cannot issue actuator commands.
6. **Flutter app** — dashboards, plant/device administration, image upload, alerts, reports and MANUAL irrigation requests.

## Runtime path

- Sensors are sampled every 30–60 seconds by default and sent to `flora/devices/{device_id}/telemetry`.
- Images are uploaded through an authenticated API/storage flow; the backend creates an analysis job and stores the returned `model_version`.
- Pump commands originate only from the app or backend AUTO policy. The backend emits one non-retained MQTT command with `command_id` and `expires_at`.
- Firmware ACK is mandatory: accepted, rejected, started, completed or failed. Duplicate command IDs are ignored after recording a duplicate ACK.
- Alerts are generated after persistence, not directly by the sensor payload.

## Trust boundaries

- Firmware never trusts the cloud for unlimited run time.
- Backend never trusts client ownership claims; it checks farm/plant/device relations.
- AI output is advisory until the safety policy validates current and calibrated sensor values.
- Database RLS protects client-visible rows; service-role queries still require explicit ownership predicates.

## Availability

- Device continues fail-safe operation during network loss and queues bounded telemetry if required.
- A pump cycle already started must stop on the local maximum-run timer even if the cloud disconnects.
- AUTO mode must be disabled until calibration and field-test data exist for the target plant/soil.
