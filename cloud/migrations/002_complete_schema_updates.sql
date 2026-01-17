-- ============================================================================
-- OPTIMIZATION SETTINGS
-- ============================================================================

-- Create system settings table for optimization control
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(100) DEFAULT 'system'
);

-- Insert default optimization setting (enabled by default)
INSERT INTO system_settings (setting_key, setting_value, description)
VALUES ('optimization_enabled', 'true', 'Automated temperature and humidity control optimization')
ON CONFLICT (setting_key) DO NOTHING;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_system_settings_key ON system_settings(setting_key);
