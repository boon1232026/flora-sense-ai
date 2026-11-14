BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    supabase_user_id uuid UNIQUE,
    email text NOT NULL UNIQUE,
    role text NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'technician', 'viewer')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE profiles (
    user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    display_name text NOT NULL,
    timezone text NOT NULL DEFAULT 'Asia/Bangkok',
    locale text NOT NULL DEFAULT 'th-TH',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE farms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name text NOT NULL,
    location text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE growing_zones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE plant_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    scientific_name text,
    default_moisture_min numeric(5,2) CHECK (default_moisture_min >= 0 AND default_moisture_min <= 100),
    default_moisture_max numeric(5,2) CHECK (default_moisture_max >= 0 AND default_moisture_max <= 100),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE plants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id uuid NOT NULL REFERENCES growing_zones(id) ON DELETE CASCADE,
    plant_type_id uuid REFERENCES plant_types(id) ON DELETE SET NULL,
    name text NOT NULL,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'removed')),
    planted_at timestamptz,
    moisture_min numeric(5,2) CHECK (moisture_min >= 0 AND moisture_min <= 100),
    moisture_max numeric(5,2) CHECK (moisture_max >= 0 AND moisture_max <= 100),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    plant_id uuid REFERENCES plants(id) ON DELETE SET NULL,
    device_key text NOT NULL UNIQUE,
    name text NOT NULL,
    mode text NOT NULL DEFAULT 'TEST' CHECK (mode IN ('TEST', 'MANUAL', 'AUTO')),
    status text NOT NULL DEFAULT 'provisioning' CHECK (status IN ('provisioning', 'online', 'offline', 'fault', 'decommissioned')),
    firmware_version text,
    last_seen_at timestamptz,
    provisioned_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sensors (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    sensor_type text NOT NULL CHECK (sensor_type IN ('soil_moisture', 'air', 'leaf_temperature', 'camera', 'pump_feedback')),
    model text,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'fault', 'inactive')),
    calibration jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sensor_readings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    plant_id uuid REFERENCES plants(id) ON DELETE SET NULL,
    sampled_at timestamptz NOT NULL,
    soil_moisture numeric(5,2) CHECK (soil_moisture >= 0 AND soil_moisture <= 100),
    air_temperature numeric(5,2),
    air_humidity numeric(5,2) CHECK (air_humidity >= 0 AND air_humidity <= 100),
    leaf_temperature numeric(5,2),
    supply_voltage numeric(6,3),
    rssi_dbm numeric(6,2),
    sensor_status jsonb NOT NULL DEFAULT '{}'::jsonb,
    raw jsonb NOT NULL DEFAULT '{}'::jsonb,
    received_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX sensor_readings_device_sample_idx
    ON sensor_readings (device_id, sampled_at);
CREATE INDEX sensor_readings_plant_time_idx
    ON sensor_readings (plant_id, sampled_at DESC);
CREATE INDEX sensor_readings_device_time_idx
    ON sensor_readings (device_id, sampled_at DESC);

CREATE TABLE plant_images (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plant_id uuid NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    uploaded_by uuid REFERENCES users(id) ON DELETE SET NULL,
    storage_path text NOT NULL,
    captured_at timestamptz NOT NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX plant_images_plant_time_idx ON plant_images (plant_id, captured_at DESC);

CREATE TABLE ai_models (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version text NOT NULL UNIQUE,
    kind text NOT NULL CHECK (kind IN ('image', 'sensor', 'fusion')),
    artifact_path text,
    metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
    trained_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ai_predictions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plant_id uuid NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    image_id uuid REFERENCES plant_images(id) ON DELETE SET NULL,
    reading_id uuid REFERENCES sensor_readings(id) ON DELETE SET NULL,
    model_id uuid NOT NULL REFERENCES ai_models(id),
    risk_level text NOT NULL CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    risk_score integer NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
    features jsonb NOT NULL DEFAULT '{}'::jsonb,
    recommendation text NOT NULL,
    analyzed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ai_predictions_plant_time_idx ON ai_predictions (plant_id, analyzed_at DESC);

CREATE TABLE alerts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plant_id uuid NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    prediction_id uuid REFERENCES ai_predictions(id) ON DELETE SET NULL,
    severity text NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    code text NOT NULL,
    message text NOT NULL,
    status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved')),
    acknowledged_by uuid REFERENCES users(id) ON DELETE SET NULL,
    acknowledged_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX alerts_plant_status_idx ON alerts (plant_id, status, created_at DESC);

CREATE TABLE notification_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id uuid REFERENCES alerts(id) ON DELETE CASCADE,
    user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    channel text NOT NULL CHECK (channel IN ('push', 'email', 'line', 'webhook')),
    destination text,
    status text NOT NULL CHECK (status IN ('queued', 'sent', 'failed')),
    error text,
    sent_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pump_settings (
    device_id uuid PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    max_run_seconds integer NOT NULL DEFAULT 120 CHECK (max_run_seconds BETWEEN 1 AND 1800),
    cooldown_seconds integer NOT NULL DEFAULT 300 CHECK (cooldown_seconds >= 0),
    auto_enabled boolean NOT NULL DEFAULT false,
    moisture_low numeric(5,2) CHECK (moisture_low >= 0 AND moisture_low <= 100),
    updated_by uuid REFERENCES users(id) ON DELETE SET NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pump_commands (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    command_id uuid NOT NULL UNIQUE,
    device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    plant_id uuid NOT NULL REFERENCES plants(id) ON DELETE CASCADE,
    requested_by uuid REFERENCES users(id) ON DELETE SET NULL,
    idempotency_key text,
    mode text NOT NULL CHECK (mode IN ('MANUAL', 'AUTO')),
    action text NOT NULL CHECK (action IN ('start', 'stop')),
    duration_seconds integer NOT NULL CHECK (duration_seconds BETWEEN 1 AND 1800),
    status text NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'queued', 'accepted', 'rejected', 'duplicate', 'expired', 'started', 'completed', 'failed', 'cancelled')),
    issued_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    acknowledged_at timestamptz,
    ack_status text,
    ack_reason text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (device_id, idempotency_key)
);
CREATE INDEX pump_commands_device_time_idx ON pump_commands (device_id, created_at DESC);

CREATE TABLE pump_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    command_id uuid REFERENCES pump_commands(id) ON DELETE SET NULL,
    device_id uuid NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    event text NOT NULL,
    reason_code text,
    started_at timestamptz,
    stopped_at timestamptz,
    runtime_seconds integer CHECK (runtime_seconds >= 0),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX pump_logs_device_time_idx ON pump_logs (device_id, created_at DESC);

CREATE TABLE device_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id uuid REFERENCES devices(id) ON DELETE SET NULL,
    event_type text NOT NULL,
    severity text NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX device_events_device_time_idx ON device_events (device_id, occurred_at DESC);

CREATE TABLE system_settings (
    key text PRIMARY KEY,
    value jsonb NOT NULL,
    description text,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER farms_updated_at BEFORE UPDATE ON farms FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER growing_zones_updated_at BEFORE UPDATE ON growing_zones FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER plants_updated_at BEFORE UPDATE ON plants FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER devices_updated_at BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER sensors_updated_at BEFORE UPDATE ON sensors FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER pump_settings_updated_at BEFORE UPDATE ON pump_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
