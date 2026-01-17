-- ============================================================================
-- INITIAL DATABASE SCHEMA
-- ============================================================================
-- This file creates all initial tables for the SProp monitoring system
-- ============================================================================

-- ============================================================================
-- SENSOR DATA TABLE
-- ============================================================================

-- Create sensor_data table for storing temperature and humidity readings
CREATE TABLE IF NOT EXISTS sensor_data (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    temperature DECIMAL(5, 2) NOT NULL,
    humidity DECIMAL(5, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index on timestamp for faster queries
CREATE INDEX IF NOT EXISTS idx_sensor_data_timestamp ON sensor_data(timestamp DESC);

-- Create index on timestamp range queries
CREATE INDEX IF NOT EXISTS idx_sensor_data_timestamp_range ON sensor_data(timestamp);

COMMENT ON TABLE sensor_data IS 'Stores temperature and humidity sensor readings from ESP32';
COMMENT ON COLUMN sensor_data.timestamp IS 'Timestamp of the sensor reading (stored as UTC)';
COMMENT ON COLUMN sensor_data.temperature IS 'Temperature in Celsius';
COMMENT ON COLUMN sensor_data.humidity IS 'Humidity percentage (0-100)';

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

-- ============================================================================
-- USER AUTHENTICATION TABLE
-- ============================================================================

-- Create users table for authentication
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

COMMENT ON TABLE users IS 'Stores user accounts for authentication';
COMMENT ON COLUMN users.username IS 'Unique username for login';
COMMENT ON COLUMN users.email IS 'Unique email address';
COMMENT ON COLUMN users.hashed_password IS 'BCrypt hashed password';
COMMENT ON COLUMN users.is_active IS 'Whether the user account is active';
COMMENT ON COLUMN users.is_admin IS 'Whether the user has admin privileges';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions on all tables to sprop_user
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE sensor_data TO sprop_user;
GRANT USAGE, SELECT ON SEQUENCE sensor_data_id_seq TO sprop_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE system_settings TO sprop_user;
GRANT USAGE, SELECT ON SEQUENCE system_settings_id_seq TO sprop_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO sprop_user;
GRANT USAGE, SELECT ON SEQUENCE users_id_seq TO sprop_user;

-- Grant default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sprop_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sprop_user;
