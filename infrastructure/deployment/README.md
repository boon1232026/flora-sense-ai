# Deployment Plan

## Local integration

```bash
cp ../../.env.example ../../.env
docker compose -f infrastructure/docker/docker-compose.yml up --build
```

## Target deployment

1. Provision one EMQX credential per ESP32 and topic ACLs for its `device_id`.
2. Deploy backend and AI service as separate containers so image/ML dependencies do not affect the C API runtime.
3. Use Supabase for auth, PostgreSQL, storage and realtime; keep the backend service-role key only in server secrets.
4. Run database migrations transactionally and back up before schema changes.
5. Send pump commands only through the backend endpoint, never directly from AI or Flutter MQTT credentials.

## Release gates

- Backend unit/integration tests pass.
- AI fallback model responds and model version is reported.
- ESP32 boot leaves pump off; TEST interlock physically blocks pump power.
- Expired, retained and duplicate commands are rejected and logged.
