# Database Design

Canonical SQL: `database/schema.sql`; RLS policy definitions: `database/policies/rls.sql`.

## Principles

- UUID primary keys.
- UTC timestamps (`timestamptz`) and local rendering in Flutter.
- Audit pump execution and AI model version.
- Store object paths instead of binary images.
- Time-series indexes are created now; TimescaleDB/partitioning can wait until measured load requires it.
- Delete is restricted for telemetry/audit records; use operational status fields where possible.

## Important relationships

`users → farms → growing_zones → plants`
`devices → sensors → sensor_readings`
`plants → plant_images → ai_predictions → alerts`
`devices → pump_settings/pump_commands → pump_logs`
`ai_models → ai_predictions`

## RLS model

Farm membership is represented by `farms.owner_user_id` or `farm_members` if expanded later. Initial policies allow users to read/write only rows connected to their farm. Service-role access bypasses RLS, so backend code must still use explicit predicates.

## Growth path

- Keep normal PostgreSQL until write volume proves otherwise.
- Consider range partitioning `sensor_readings` and `pump_logs` by month first.
- Evaluate TimescaleDB only if continuous aggregates/compression materially reduce work.
