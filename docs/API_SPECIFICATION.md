# API Specification

Canonical OpenAPI: `contracts/api/openapi.yaml`.

## AuthN/AuthZ

Clients authenticate with Supabase Auth and send a bearer token. Backend resolves the user, then authorizes `farm_id`, `plant_id` and `device_id` against database ownership before mutation.

The service-role key may only exist in backend configuration. RLS remains enabled for direct client reads.

## Main resources

- `GET /v1/dashboard`
- `GET /v1/plants`, `POST /v1/plants`, `GET /v1/plants/{id}`
- `GET /v1/plants/{id}/readings?from&to`
- `GET /v1/plants/{id}/predictions`
- `POST /v1/plants/{id}/images`
- `GET /v1/alerts`, `POST /v1/alerts/{id}/ack`
- `GET /v1/devices`, `PATCH /v1/devices/{id}`
- `POST /v1/devices/{id}/commands`
- `GET /v1/pump-commands/{id}`

## Idempotency

`POST /v1/devices/{id}/commands` requires an `Idempotency-Key` header. The backend stores the key and returns the existing command for a retry instead of producing a second pump command.

## Errors

Use RFC 9457 problem details:

- `400 invalid_payload`
- `401 unauthenticated`
- `403 forbidden`
- `404 not_found`
- `409 command_conflict`
- `422 unsafe_or_expired`
- `503 downstream_unavailable`
