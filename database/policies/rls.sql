-- Enable row-level security for client-accessible resources. Backend service-role
-- queries must still include explicit ownership predicates.
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE growing_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE plants ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensors ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE plant_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE pump_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pump_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE pump_logs ENABLE ROW LEVEL SECURITY;

-- Helper assumes request-local parameter `app.user_id`, set by the backend/session.
-- Supabase deployments can replace it with `(auth.uid())::uuid` and an auth-user mapping.
CREATE OR REPLACE FUNCTION app_user_id() RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION is_farm_member(target_farm uuid) RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT EXISTS (
        SELECT 1 FROM farms f
        JOIN users u ON u.id = f.owner_user_id
        WHERE f.id = target_farm
          AND u.supabase_user_id = app_user_id()
    )
$$;

CREATE POLICY profiles_self ON profiles
    USING (user_id IN (SELECT id FROM users WHERE supabase_user_id = app_user_id()));

CREATE POLICY farms_owner ON farms
    USING (owner_user_id IN (SELECT id FROM users WHERE supabase_user_id = app_user_id()));

CREATE POLICY zones_member ON growing_zones
    USING (is_farm_member(farm_id));

CREATE POLICY plants_member ON plants
    USING (EXISTS (
        SELECT 1 FROM growing_zones z
        WHERE z.id = plants.zone_id AND is_farm_member(z.farm_id)
    ));

CREATE POLICY devices_member ON devices
    USING (is_farm_member(farm_id));

CREATE POLICY sensors_member ON sensors
    USING (EXISTS (
        SELECT 1 FROM devices d WHERE d.id = sensors.device_id AND is_farm_member(d.farm_id)
    ));

CREATE POLICY readings_member ON sensor_readings
    USING (EXISTS (
        SELECT 1 FROM devices d WHERE d.id = sensor_readings.device_id AND is_farm_member(d.farm_id)
    ));

CREATE POLICY images_member ON plant_images
    USING (EXISTS (
        SELECT 1 FROM plants p
        JOIN growing_zones z ON z.id = p.zone_id
        WHERE p.id = plant_images.plant_id AND is_farm_member(z.farm_id)
    ));

CREATE POLICY predictions_member ON ai_predictions
    USING (EXISTS (
        SELECT 1 FROM plants p
        JOIN growing_zones z ON z.id = p.zone_id
        WHERE p.id = ai_predictions.plant_id AND is_farm_member(z.farm_id)
    ));

CREATE POLICY alerts_member ON alerts
    USING (EXISTS (
        SELECT 1 FROM plants p
        JOIN growing_zones z ON z.id = p.zone_id
        WHERE p.id = alerts.plant_id AND is_farm_member(z.farm_id)
    ));

CREATE POLICY pump_settings_member ON pump_settings
    USING (EXISTS (
        SELECT 1 FROM devices d WHERE d.id = pump_settings.device_id AND is_farm_member(d.farm_id)
    ));

CREATE POLICY pump_commands_member ON pump_commands
    USING (EXISTS (
        SELECT 1 FROM devices d WHERE d.id = pump_commands.device_id AND is_farm_member(d.farm_id)
    ));

CREATE POLICY pump_logs_member ON pump_logs
    USING (EXISTS (
        SELECT 1 FROM devices d WHERE d.id = pump_logs.device_id AND is_farm_member(d.farm_id)
    ));
