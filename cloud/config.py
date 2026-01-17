"""
Configuration settings for the sprop monitoring backend
"""
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Database configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "sprop_db")
DB_USER = os.getenv("DB_USER", "sprop_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "db1234")
DB_SSL_MODE = os.getenv("DB_SSL_MODE", "require")  # Options: disable, allow, prefer, require, verify-ca, verify-full

# Database connection string with SSL
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}?sslmode={DB_SSL_MODE}"

# MQTT configuration
MQTT_BROKER_HOST = os.getenv("MQTT_BROKER_HOST", "localhost")
MQTT_BROKER_PORT = int(os.getenv("MQTT_BROKER_PORT", "8883"))
MQTT_USERNAME = os.getenv("MQTT_USERNAME", None)
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD", None)
MQTT_USE_TLS = os.getenv("MQTT_USE_TLS", "true").lower() == "true"
MQTT_CA_CERTS = os.getenv("MQTT_CA_CERTS", None) 
MQTT_CERTFILE = os.getenv("MQTT_CERTFILE", None)  
MQTT_KEYFILE = os.getenv("MQTT_KEYFILE", None) 

# MQTT Topics
MQTT_SENSOR_TOPIC = os.getenv("MQTT_SENSOR_TOPIC", "sprop/sensor/data")
MQTT_CMD_FAN_TOPIC = "sprop/cmd/fan"
MQTT_CMD_LID_TOPIC = "sprop/cmd/lid"
MQTT_CMD_VALVE_TOPIC = "sprop/cmd/valve"
MQTT_STATUS_FAN_TOPIC = "sprop/status/fan"
MQTT_STATUS_LID_TOPIC = "sprop/status/lid"
MQTT_STATUS_VALVE_TOPIC = "sprop/status/valve"

# Optimal ranges for orchid care
# Temperature: 18-24°C (65-75°F) ideal for common orchids (Phalaenopsis, Cattleya, Dendrobium)
TEMP_OPTIMAL_MIN = float(os.getenv("TEMP_OPTIMAL_MIN", "18.0"))
TEMP_OPTIMAL_MAX = float(os.getenv("TEMP_OPTIMAL_MAX", "24.0"))
TEMP_CRITICAL_HIGH = float(os.getenv("TEMP_CRITICAL_HIGH", "30.0"))  # Emergency cooling threshold
TEMP_CRITICAL_LOW = float(os.getenv("TEMP_CRITICAL_LOW", "10.0"))  # Emergency heating threshold

# Humidity: 40-70% relative humidity (orchids prefer higher end)
HUMIDITY_OPTIMAL_MIN = float(os.getenv("HUMIDITY_OPTIMAL_MIN", "40.0"))
HUMIDITY_OPTIMAL_MAX = float(os.getenv("HUMIDITY_OPTIMAL_MAX", "70.0"))

# API configuration
API_HOST = os.getenv("API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("API_PORT", "8000"))
API_SSL_CERTFILE = os.getenv("API_SSL_CERTFILE", None)  # Path to SSL certificate file
API_SSL_KEYFILE = os.getenv("API_SSL_KEYFILE", None)  # Path to SSL private key file

# JWT Authentication configuration
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-this-in-production")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))  # 24 hours default
