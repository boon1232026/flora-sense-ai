BEGIN;

INSERT INTO plant_types (name, scientific_name, default_moisture_min, default_moisture_max) VALUES
    ('Basil', 'Ocimum basilicum', 35, 70),
    ('Lettuce', 'Lactuca sativa', 40, 75),
    ('Tomato', 'Solanum lycopersicum', 35, 65)
ON CONFLICT (name) DO NOTHING;

INSERT INTO ai_models (version, kind, metrics, trained_at) VALUES
    ('flora-rules-v1', 'fusion', '{"baseline": true}', now())
ON CONFLICT (version) DO NOTHING;

INSERT INTO system_settings (key, value, description) VALUES
    ('mqtt.schema_version', '1', 'Current MQTT payload schema version'),
    ('pump.default_max_run_seconds', '120', 'Default device pump runtime bound'),
    ('ai.auto_enabled', 'false', 'Global gate for AI-assisted irrigation')
ON CONFLICT (key) DO NOTHING;

COMMIT;
